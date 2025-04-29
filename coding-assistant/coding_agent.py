import os, torch, streamlit as st
from transformers import AutoTokenizer, AutoModelForCausalLM
from huggingface_hub import snapshot_download

MODEL_DIR = "coding_agent_model"
REPO_ID   = "deepseek-ai/deepseek-coder-1.3b-instruct"

@st.cache_resource
def download_model(token: str):
    local_dir = os.path.join(MODEL_DIR, REPO_ID.replace("/", "--"))
    if not os.path.isdir(local_dir):
        snapshot_download(repo_id=REPO_ID, local_dir=local_dir, token=token)
    return local_dir

@st.cache_resource
def load_model(token: str):
    path  = download_model(token)
    tok   = AutoTokenizer.from_pretrained(path, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        path, trust_remote_code=True,
        torch_dtype=(torch.bfloat16 if torch.cuda.is_available() else torch.float32)
    )
    if torch.cuda.is_available():
        model = model.cuda()
    return tok, model

_history = []
def generate_code_response(prompt: str, model_choice: str, hf_token: str, mode: str="chat") -> str:
    try:
        tok, model = load_model(hf_token)
        if mode == "chat":
            msgs = _history + [{"role":"user","content":prompt}]
            inp  = tok.apply_chat_template(msgs, add_generation_prompt=True, return_tensors="pt")
            inp  = inp.to(model.device)
            out  = model.generate(
                inp["input_ids"], max_new_tokens=6000,
                do_sample=False, top_k=50, top_p=0.95
            )
            reply = tok.decode(out[0][inp["input_ids"].shape[-1]:], skip_special_tokens=True)

        elif mode == "completion":
            enc   = tok(prompt, return_tensors="pt").to(model.device)
            out   = model.generate(**enc, max_length=6000)
            reply = tok.decode(out[0], skip_special_tokens=True)

        else:
            raise ValueError("Mode must be chat or completion")

        _history.append({"role":"user","content":prompt})
        _history.append({"role":"assistant","content":reply})
        return reply

    except Exception as e:
        return f"❌ Error: {e}"

def reset_history():
    global _history
    _history = []
