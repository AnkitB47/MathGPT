import os, threading
import torch, streamlit as st
from transformers import AutoTokenizer, AutoModelForCausalLM
from huggingface_hub import snapshot_download

MODEL_DIR = os.path.join(os.getcwd(), "coding_agent_model")
_repo    = "deepseek-ai/deepseek-coder-1.3b-instruct"
_lock    = threading.Lock()

@st.cache_resource
def download_model():
    hf_token = os.environ["HF_TOKEN"]
    # snapshot_download returns the actual path it created
    with _lock:
        return snapshot_download(
            repo_id=_repo,
            cache_dir=MODEL_DIR,
            token=hf_token
        )

@st.cache_resource
def load_deepseek():
    path = download_model()
    tokenizer = AutoTokenizer.from_pretrained(path, trust_remote_code=True)
    model     = AutoModelForCausalLM.from_pretrained(path, trust_remote_code=True,
                    torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32
                ).to("cuda" if torch.cuda.is_available() else "cpu")
    model.eval()
    return tokenizer, model

history = []

def generate_code_response(prompt: str, model_choice: str, mode: str="chat") -> str:
    lc = model_choice.lower()
    if "deepseek-coder-1.3b-instruct" not in lc:
        # now a substring check, not exact match
        return f"❌ Error: Invalid model choice {model_choice!r}. Only DeepSeek-coder is supported."

    tokenizer, model = load_deepseek()

    if mode == "chat":
        inputs  = tokenizer.apply_chat_template(
                     history + [{"role":"user","content":prompt}],
                     add_generation_prompt=True,
                     return_tensors="pt"
                   ).to(model.device)
        outputs = model.generate(
                     inputs["input_ids"],
                     max_new_tokens=512,
                     do_sample=False,
                     top_k=50, top_p=0.95,
                     eos_token_id=tokenizer.eos_token_id
                   )
        gen     = outputs[0][ inputs["input_ids"].shape[-1] : ]
        reply   = tokenizer.decode(gen, skip_special_tokens=True)

    elif mode == "completion":
        inputs  = tokenizer(prompt, return_tensors="pt").to(model.device)
        outputs = model.generate(**inputs, max_new_tokens=128,
                                  eos_token_id=tokenizer.eos_token_id)
        reply   = tokenizer.decode(outputs[0], skip_special_tokens=True)

    else:
        return "❌ Error: Invalid mode. Use 'chat' or 'completion'."

    history.append({"role":"user", "content":prompt})
    history.append({"role":"assistant", "content":reply})
    return reply

def reset_history():
    global history
    history = []
