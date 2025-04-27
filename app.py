import streamlit as st
from langchain_groq import ChatGroq
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain_community.utilities import WikipediaAPIWrapper
from langchain.agents import Tool, initialize_agent, AgentType
from langchain_community.callbacks.streamlit import StreamlitCallbackHandler

import torch  # for cleanup
import gc     # for cleanup

# ── UI SETUP ────────────────────────────────────────────────────────────────────
st.set_page_config(page_title="🤖 Math & Logic Assistant", page_icon="🧠")
st.title("🤖 Math & Logic Assistant")
st.markdown("Ask **complex math** or **reasoning** questions and get step-by-step solutions.")

# ── GROQ KEY & MODEL ─────────────────────────────────────────────────────────────
groq_api_key = st.sidebar.text_input("🔑 Groq API Key", type="password")
if not groq_api_key:
    st.warning("Please enter your Groq API key to continue.")
    st.stop()

selected_model = st.sidebar.selectbox("🤖 Choose LLM Model", [
    "llama3-70b-8192",
    "gemma2-9b-it",
    "deepseek-r1-distill-llama-70b"
])

# ── LLM INITIALIZATION ──────────────────────────────────────────────────────────
llm = ChatGroq(model=selected_model, groq_api_key=groq_api_key, streaming=True)

# ── TOOLS SETUP ─────────────────────────────────────────────────────────────────
wiki = WikipediaAPIWrapper()
wikipedia_tool = Tool(
    name="Wikipedia",
    func=wiki.run,
    description="Factual information from Wikipedia."
)

from sympy import symbols, factorial, log, sin, cos, tan, simplify, integrate, diff, Eq, solve
from sympy.abc import x, y, z, t

def safe_math_solver(query: str) -> str:
    try:
        # factorial digit‐count shortcut
        if "digits in" in query.lower() and "factorial" in query.lower():
            import math
            n = int(''.join(filter(str.isdigit, query)))
            digit_count = math.floor(sum(math.log10(i) for i in range(1, n+1))) + 1
            return f"Number of digits in {n}! is {digit_count}"

        # symbolic calculus shortcuts
        if any(op in query for op in ["integrate", "diff", "solve"]):
            expr = simplify(query.replace("^", "**"))
            return str(eval(expr))

        # plain‐eval with safe namespace
        result = eval(
            query,
            {"__builtins__": None},
            {
                "factorial": factorial, "log": log,
                "sin": sin, "cos": cos, "tan": tan,
                "x": x, "y": y, "z": z, "t": t,
                "diff": diff, "integrate": integrate,
                "solve": solve, "Eq": Eq
            }
        )
        return str(result)
    except Exception as e:
        return f"❌ Safe Math Error: {e}"

math_tool = Tool(
    name="Calculator",
    func=safe_math_solver,
    description="Advanced math solver."
)

reasoning_prompt = PromptTemplate(
    input_variables=["question"],
    template="""
You are a super-intelligent agent capable of solving math, logical reasoning, aptitude and coding tasks.
You must:
- Avoid unsupported code execution.
- Prefer symbolic math and algebraic simplification.
- Clearly explain results in steps.

Question: {question}
Answer:
"""
)

reasoning_chain = LLMChain(llm=llm, prompt=reasoning_prompt)
reasoning_tool = Tool(
    name="Reasoning",
    func=reasoning_chain.run,
    description="Solves logic and reasoning problems."
)

tools = [wikipedia_tool, math_tool, reasoning_tool]

agent_executor = initialize_agent(
    tools=tools,
    llm=llm,
    agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True,
    handle_parsing_errors=True,
)

# ── CHAT UX ─────────────────────────────────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state.messages = [
        {"role": "assistant", "content": "Hi! I'm your Math & Logic Assistant. Ask me anything!"}
    ]

for msg in st.session_state.messages:
    st.chat_message(msg["role"]).write(msg["content"])

user_input = st.chat_input("Ask your math or logic question here…")

if user_input:
    st.session_state.messages.append({"role": "user", "content": user_input})
    st.chat_message("user").write(user_input)

    with st.chat_message("assistant"):
        handler = StreamlitCallbackHandler(st.container(), expand_new_thoughts=False)
        try:
            answer = agent_executor.run(user_input, callbacks=[handler])
        except Exception as err:
            answer = f"❌ Error: {err}"

        st.session_state.messages.append({"role": "assistant", "content": answer})
        st.write(answer)

        # ── cleanup GPU & Python mem ───────────────────────────────────────────
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        gc.collect()
