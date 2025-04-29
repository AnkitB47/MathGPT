import os, gc, torch, streamlit as st
from coding_agent import generate_code_response, reset_history
from peft import PeftModel, PeftConfig
from transformers import AutoModelForCausalLM, AutoTokenizer

# ── UI SETUP ────────────────────────────────────────────────
st.set_page_config(page_title="💻 Coding Assistant", page_icon="🤖")
st.title("💻 Coding Assistant")
st.markdown("Chat, complete, or use the fine-tuned model for coding tasks.")

# ── Sidebar ────────────────────────────────────────────────
hf_token      = os.getenv("HF_TOKEN")
if not hf_token:
    st.sidebar.error("🚨 Set HF_TOKEN as an env var to use this app.")
    st.stop()

mode          = st.sidebar.selectbox("Mode", ["chat", "completion", "fine-tuned"])
  
# ── Chat history ──────────────────────────────────────────
if "history" not in st.session_state:
    st.session_state.history = []

# ── Input area ────────────────────────────────────────────
prompt = st.text_area("Enter your prompt here", height=120)
if st.button("Submit") and prompt:
    with st.spinner("💡 Generating…"):
        if mode == "fine-tuned":
            # load LoRA-fine-tuned adapter
            adapter_path = "output/qlora-deepseek/adapters"
            config       = PeftConfig.from_pretrained(adapter_path)
            base_model   = AutoModelForCausalLM.from_pretrained(
                config.base_model_name_or_path,
                device_map="auto", torch_dtype=torch.float16, trust_remote_code=True
            )
            model        = PeftModel.from_pretrained(base_model, adapter_path).eval().to(
                torch.device("cuda") if torch.cuda.is_available() else torch.device("cpu")
            )
            tokenizer    = AutoTokenizer.from_pretrained(config.base_model_name_or_path, trust_remote_code=True)

            # ensure tokens
            if tokenizer.eos_token is None:
                tokenizer.eos_token = tokenizer.pad_token or "</s>"

            chat_hist = "\n".join(f"{m['role']}: {m['content']}" for m in st.session_state.history + [{"role":"user","content":prompt}])
            inputs    = tokenizer(chat_hist, return_tensors="pt", truncation=True, max_length=2048).to(model.device)
            outputs   = model.generate(
                **inputs,
                max_new_tokens=6000,
                do_sample=True, temperature=0.7, top_p=0.95,
                pad_token_id=tokenizer.eos_token_id,
                eos_token_id=tokenizer.eos_token_id
            )
            text      = tokenizer.decode(outputs[0], skip_special_tokens=True)
        else:
            text = generate_code_response(
                prompt=prompt,
                model_choice="deepseek-coder-1.3b-instruct",
                hf_token=hf_token,
                mode=mode
            )

    # append & display
    st.session_state.history.append(("You", prompt))
    st.session_state.history.append(("Bot", text))

# ── Render history ─────────────────────────────────────────
for speaker, txt in st.session_state.history:
    st.markdown(f"**{speaker}:**  \n```{txt}```")

# ── Reset button ──────────────────────────────────────────
if st.sidebar.button("Reset History"):
    reset_history()
    st.experimental_rerun()

# ── Cleanup ────────────────────────────────────────────────
if torch.cuda.is_available():
    torch.cuda.empty_cache()
gc.collect()
