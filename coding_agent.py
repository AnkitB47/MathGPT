import os
import threading
import torch
import streamlit as st
from transformers import AutoTokenizer, AutoModelForCausalLM
from huggingface_hub import snapshot_download

MODEL_DIR = os.path.join(os.getcwd(), "model_cache")
_repo = "deepseek-ai/deepseek-coder-1.3b-instruct"
_download_lock = threading.Lock()

@st.cache_resource(show_spinner=False)
def download_model():
    hf_token = os.environ["HF_TOKEN"]
    target = os.path.join(MODEL_DIR, _repo.replace("/", "__"))
    with _download_lock:
        if not os.path.isdir(target):
            snapshot_download(
                repo_id=_repo,
                cache_dir=MODEL_DIR,
                token=hf_token
            )
    return target

@st.cache_resource(show_spinner=False)
def load_deepseek():
    model_path = download_model()
    tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        trust_remote_code=True,
        torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32
    ).to("cuda" if torch.cuda.is_available() else "cpu")
    return tokenizer, model

# Global chat history
history = []

def generate_code_response(prompt: str, model_choice: str, hf_token: str, mode: str = "chat") -> str:
    try:
        lc = model_choice.lower()
        if "deepseek-coder-1.3b-instruct" in lc:
            tokenizer, model = load_deepseek()

            if mode == "chat":
                inputs = tokenizer.apply_chat_template(
                    history + [{"role":"user","content":prompt}],
                    add_generation_prompt=True,
                    return_tensors="pt"
                ).to(model.device)
                outputs = model.generate(
                    inputs["input_ids"],
                    max_new_tokens=512,
                    do_sample=False,
                    top_k=50,
                    top_p=0.95,
                    eos_token_id=tokenizer.eos_token_id
                )
                reply = tokenizer.decode(outputs[0][len(inputs["input_ids"]):], skip_special_tokens=True)

            elif mode == "completion":
                inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
                outputs = model.generate(**inputs, max_length=128)
                reply = tokenizer.decode(outputs[0], skip_special_tokens=True)

            else:
                raise ValueError("Invalid mode. Use 'chat' or 'completion'.")

        else:
            # allow any other string containing “deepseek” in the future
            raise ValueError(f"Invalid model choice {model_choice!r}. Only DeepSeek is supported.")

        # update chat history
        history.append({"role":"user","content":prompt})
        history.append({"role":"assistant","content":reply})
        return reply

    except Exception as e:
        return f"❌ Error: {str(e)}"

def reset_history():
    global history
    history = []
