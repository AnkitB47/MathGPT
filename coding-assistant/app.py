import os, gc, torch, streamlit as st
from coding_agent import generate_code_response

st.set_page_config(page_title="💻 Coding Assistant", page_icon="🤖")
st.title("💻 Coding Assistant")

hf_token = os.getenv("HF_TOKEN", "")
if not hf_token:
    st.sidebar.error("🚨 Set HF_TOKEN as an env var to use this app.")
    st.stop()

mode = st.sidebar.selectbox("Mode", ["chat", "completion", "fine-tuned"])

prompt = st.text_area("Enter your prompt here", height=150)
if st.button("Submit") and prompt.strip():
    with st.spinner("💡 Generating…"):
        reply = generate_code_response(prompt, hf_token, mode)
    st.markdown(f"**Assistant:**  \n```{reply}```")

# free GPU memory between runs
if torch.cuda.is_available():
    torch.cuda.empty_cache()
gc.collect()
