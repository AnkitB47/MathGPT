import os
import streamlit as st
from langchain_groq import ChatGroq
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain_community.utilities import WikipediaAPIWrapper
from langchain.agents import Tool, initialize_agent, AgentType
from langchain_community.callbacks.streamlit import StreamlitCallbackHandler
from coding_agent import generate_code_response

from peft import PeftModel, PeftConfig
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import gc

# ---------------------- UI SETUP ----------------------
st.set_page_config(page_title="🤖 Math, Logic & Code Assistant", page_icon="🧠")
st.title("🤖 Math, Logic & Code Assistant")
st.markdown("""
Ask **complex math**, **reasoning**, or **coding** questions. Select an LLM model and get step-by-step solutions.
""")

# Sidebar - Mode selection
mode = st.sidebar.radio("Choose Mode", ["General Assistant", "Coding Assistant"])

# ---------------------- GENERAL ASSISTANT ----------------------
if mode == "General Assistant":
    groq_api_key = st.sidebar.text_input("🔑 Groq API Key (for General Assistant)", type="password")
    if not groq_api_key:
        st.warning("Please enter your Groq API key to continue.")
        st.stop()

    selected_model = st.sidebar.selectbox("🤖 Choose LLM Model", [
        "llama3-70b-8192",
        "gemma2-9b-it",
        "deepseek-r1-distill-llama-70b"
    ])
    llm = ChatGroq(model=selected_model, groq_api_key=groq_api_key, streaming=True)

    # Wikipedia Tool
    wiki = WikipediaAPIWrapper()
    wikipedia_tool = Tool(name="Wikipedia", func=wiki.run, description="Factual information from Wikipedia.")

    # Math Tool
    from sympy import symbols, factorial, log, sin, cos, tan, simplify, integrate, diff, Eq, solve
    from sympy.abc import x, y, z, t

    def safe_math_solver(query: str) -> str:
        try:
            if "digits in" in query.lower() and "factorial" in query.lower():
                import math
                n = int(''.join(filter(str.isdigit, query)))
                digit_count = math.floor(sum([math.log10(i) for i in range(1, n+1)])) + 1
                return f"Number of digits in {n}! is {digit_count}"
            if any(op in query for op in ["integrate", "diff", "solve"]):
                expr = simplify(query.replace("^", "**"))
                result = eval(expr)
                return str(result)
            result = eval(query, {"__builtins__": None}, {
                "factorial": factorial, "log": log, "sin": sin, "cos": cos, "tan": tan,
                "x": x, "y": y, "z": z, "t": t, "diff": diff, "integrate": integrate,
                "solve": solve, "Eq": Eq
            })
            return str(result)
        except Exception as e:
            return f"❌ Safe Math Error: {str(e)}"

    math_tool = Tool(name="Calculator", func=safe_math_solver, description="Advanced math solver.")

    reasoning_prompt = PromptTemplate(
        input_variables=["question"],
        template="""
You are a super-intelligent agent capable of solving math, logic and programming tasks.
You must:
- Avoid unsupported code execution like math.prod or numexpr.eval.
- Prefer symbolic math, logic, and algebraic simplification.
- Use known formulas for factorials, logarithms, and calculus.
- Clearly explain results in steps.
Question: {question}
Answer:
"""
    )

    reasoning_chain = LLMChain(llm=llm, prompt=reasoning_prompt)
    reasoning_tool = Tool(name="Reasoning & Coding", func=reasoning_chain.run, description="Solves logic/math/code reasoning.")

    tools = [wikipedia_tool, reasoning_tool, math_tool]

    agent_executor = initialize_agent(
        tools=tools,
        llm=llm,
        agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
        verbose=True,
        handle_parsing_errors=True,
    )

# ---------------------- CODING ASSISTANT ----------------------
elif mode == "Coding Assistant":
    # HF_TOKEN is provided via environment in production (Cloud Run, GH Actions)
    hf_token = os.environ.get("HF_TOKEN")
    deepseek_mode = st.sidebar.selectbox("⚙️ DeepSeek Mode", ["chat", "completion", "fine-tuned"])
    if deepseek_mode != "fine-tuned" and not hf_token:
        st.warning("Hugging Face token not found. Please set HF_TOKEN as env var.")
        st.stop()

# ---------------------- Chat Memory ----------------------
if "messages" not in st.session_state:
    st.session_state["messages"] = [
        {"role": "assistant", "content": "Hi! I'm your advanced assistant for solving math, logic, and code problems. Ask away!"}
    ]

for msg in st.session_state["messages"]:
    st.chat_message(msg["role"]).write(msg["content"])

prompt = st.chat_input("Ask me a math, logic or coding problem...")

if prompt:
    st.session_state["messages"].append({"role": "user", "content": prompt})
    st.chat_message("user").write(prompt)

    with st.chat_message("assistant"):
        st_cb = StreamlitCallbackHandler(st.container(), expand_new_thoughts=False)

        if mode == "Coding Assistant":
            with st.spinner("Generating code with DeepSeek..."):
                try:
                    if deepseek_mode == "fine-tuned":
                        adapter_path = "output/qlora-deepseek/adapters"
                        config = PeftConfig.from_pretrained(adapter_path)
                        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
                        base_model = AutoModelForCausalLM.from_pretrained(
                            config.base_model_name_or_path,
                            device_map="auto",
                            torch_dtype=torch.float16,
                            trust_remote_code=True
                        )
                        model = PeftModel.from_pretrained(base_model, adapter_path)
                        tokenizer = AutoTokenizer.from_pretrained(config.base_model_name_or_path)
                        # Fix for missing eos_token
                        if tokenizer.eos_token is None:
                            tokenizer.eos_token = tokenizer.pad_token or "</s>"

                        # Ensure pad_token_id and eos_token_id are defined
                        pad_token_id = tokenizer.pad_token_id or tokenizer.eos_token_id
                        eos_token_id = tokenizer.eos_token_id

                        model.eval()
                        model.to(device)  # push to device (CPU or GPU)

                        max_input_tokens = 2048
                        max_output_tokens = 2048

                        # Truncate chat history token-wise, not string-wise
                        chat_history = "\n".join([f"{m['role']}: {m['content']}" for m in st.session_state["messages"]])
                        inputs = tokenizer(chat_history, return_tensors="pt", truncation=True, max_length=max_input_tokens).to(device)
                        
                        outputs = model.generate(
                            input_ids=inputs["input_ids"],
                            max_new_tokens=max_output_tokens,
                            do_sample=True,
                            temperature=0.7,
                            top_p=0.95,
                            pad_token_id=eos_token_id,
                            eos_token_id=eos_token_id
                        )
                        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
                        response = response.split("assistant:", 1)[-1].strip()  # Remove repeated prompt
                        response = f"```python\n{response}\n````
                    else:
                        response = generate_code_response(
                            prompt=prompt,
                            hf_token=hf_token,
                            model_choice="deepseek-ai/deepseek-coder-1.3b-instruct",
                            mode=deepseek_mode
                        )
                        if deepseek_mode == "completion":
                            response = f"```python\n{response.strip()}\n```"
                except Exception as e:
                    response = f"❌ Error generating code: {str(e)}"

        else:
            try:
                response = agent_executor.run(prompt, callbacks=[st_cb])
            except Exception as e:
                response = f"❌ Error: {str(e)}"

        st.session_state["messages"].append({"role": "assistant", "content": response})
        st.write(response)

        # ── clean up GPU & Python memory after each response ──
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        gc.collect()
