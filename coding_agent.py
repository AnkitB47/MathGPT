import os
import torch
import streamlit as st
from transformers import AutoTokenizer, AutoModelForCausalLM
from huggingface_hub import snapshot_download

MODEL_DIR = os.path.join(os.getcwd(), "coding_agent_model")

@st.cache_resource(show_spinner=False)
def download_model(hf_token: str):
    deepseek_path = os.path.join(MODEL_DIR, "deepseek-ai--deepseek-coder-1.3b-instruct")

    if not os.path.exists(deepseek_path):
        snapshot_download(
            repo_id="deepseek-ai/deepseek-coder-1.3b-instruct",
            local_dir=deepseek_path,
            token=hf_token
        )
    return deepseek_path

@st.cache_resource(show_spinner=False)
def load_deepseek(hf_token: str):
    model_path = download_model(hf_token)
    tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        trust_remote_code=True,
        torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32
    ).cuda()
    return tokenizer, model

# Global chat history
history = []

def generate_code_response(prompt: str, model_choice: str, hf_token: str, mode: str = "chat") -> str:
    try:
        if model_choice.lower() == "deepseek-coder-1.3b-instruct":
            tokenizer, model = load_deepseek(hf_token)

            if mode == "chat":
                messages = history + [{"role": "user", "content": prompt}]
                inputs = tokenizer.apply_chat_template(messages, add_generation_prompt=True, return_tensors="pt").to(model.device)
                outputs = model.generate(inputs, max_new_tokens=512, do_sample=False, top_k=50, top_p=0.95, num_return_sequences=1, eos_token_id=tokenizer.eos_token_id)
                reply = tokenizer.decode(outputs[0][len(inputs[0]):], skip_special_tokens=True)

            elif mode == "completion":
                inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
                outputs = model.generate(**inputs, max_length=128)
                reply = tokenizer.decode(outputs[0], skip_special_tokens=True)

            else:
                raise ValueError("Invalid mode. Use 'chat' or 'completion'.")

        else:
            raise ValueError("Invalid model choice. Only DeepSeek is supported.")

        history.append({"role": "user", "content": prompt})
        history.append({"role": "assistant", "content": reply})
        return reply

    except Exception as e:
        return f"❌ Error: {str(e)}"

def reset_history():
    global history
    history = []
