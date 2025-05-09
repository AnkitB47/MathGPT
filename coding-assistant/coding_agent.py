import os
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel, PeftConfig
from huggingface_hub import snapshot_download
from functools import lru_cache

REPO_ID      = "deepseek-ai/deepseek-coder-1.3b-instruct"
ADAPTER_PATH = "output/qlora-deepseek/adapters"
CACHE_DIR    = "coding_agent_model"

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

@lru_cache(maxsize=1)
def _get_base_model(token: str):
    """
    Downloads the HuggingFace repo if needed, then returns (tokenizer, model).
    """
    local_dir = os.path.join(CACHE_DIR, REPO_ID.replace("/", "--"))
    if not os.path.isdir(local_dir):
        snapshot_download(repo_id=REPO_ID, local_dir=local_dir, token=token)
    tok = AutoTokenizer.from_pretrained(local_dir, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        local_dir,
        trust_remote_code=True,
        torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32
    ).to(device).eval()
    return tok, model

@lru_cache(maxsize=1)
def _get_finetuned_model(token: str):
    """
    Loads the base model, then injects your LoRA adapter.
    """
    tok, base_model = _get_base_model(token)
    # load adapter config
    peft_config = PeftConfig.from_pretrained(ADAPTER_PATH)
    # wrap in PEFT
    model = PeftModel.from_pretrained(
        base_model, ADAPTER_PATH,
        torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32
    ).to(device).eval()
    return tok, model

def generate_code_response(prompt: str, hf_token: str, mode: str = "chat") -> str:
    """
    mode: one of "chat", "completion", "fine-tuned"
    """
    try:
        if mode == "fine-tuned":
            tok, model = _get_finetuned_model(hf_token)
        else:
            tok, model = _get_base_model(hf_token)

        # single-sequence prompt
        inputs = tok(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=2048
        ).to(device)

        # adjust sampling vs greedy
        gen_kwargs = dict(
            **inputs,
            max_new_tokens=2048,
            do_sample=(mode != "chat"),  # sample only for completion/chat as you like
            top_k=50,
            top_p=0.95
        )
        out = model.generate(**gen_kwargs)
        return tok.decode(out[0], skip_special_tokens=True)

    except Exception as e:
        # bubble up so Streamlit sees it
        return f"❌ Error: {e}"
