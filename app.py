import streamlit as st
from langchain_groq import ChatGroq
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain_community.utilities import WikipediaAPIWrapper
from langchain.agents import Tool, initialize_agent, AgentType
from langchain_community.callbacks.streamlit import StreamlitCallbackHandler

# ---------------------- UI SETUP ----------------------
st.set_page_config(page_title="🤖 Math & Logic Assistant", page_icon="🧠")
st.title("🤖 Math & Logic Assistant")
st.markdown("""
Ask **complex math** or **reasoning** questions. Select an LLM model and get step-by-step solutions.
""")

# Sidebar – Groq key + model choice
groq_api_key = st.sidebar.text_input("🔑 Groq API Key", type="password")
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
wikipedia_tool = Tool(
    name="Wikipedia",
    func=wiki.run,
    description="Factual information from Wikipedia."
)

# Math Tool (Sympy‐powered)
from sympy import symbols, factorial, log, sin, cos, tan, simplify, integrate, diff, Eq, solve
from sympy.abc import x, y, z, t

def safe_math_solver(query: str) -> str:
    try:
        if "digits in" in query.lower() and "factorial" in query.lower():
            import math
            n = int(''.join(filter(str.isdigit, query)))
            digit_count = math.floor(sum(math.log10(i) for i in range(1, n+1))) + 1
            return f"Number of digits in {n}! is {digit_count}"
        if any(op in query for op in ["integrate", "diff", "solve"]):
            expr = simplify(query.replace("^", "**"))
            return str(eval(expr))
        result = eval(
            query,
            {"__builtins__": None},
            {
                "factorial": factorial,
                "log": log,
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

# Chain prompt
reasoning_prompt = PromptTemplate(
    input_variables=["question"],
    template="""
You are a super‐intelligent agent capable of solving math and reasoning tasks.
You must:
- Avoid unsupported code execution.
- Prefer symbolic math, logic, and algebraic simplification.
- Use known formulas for factorials, logarithms, and calculus.
- Clearly explain result steps.
Question: {question}
Answer:
"""
)

reasoning_chain = LLMChain(llm=llm, prompt=reasoning_prompt)
reasoning_tool = Tool(
    name="Reasoning",
    func=reasoning_chain.run,
    description="Solves logic/math reasoning."
)

tools = [wikipedia_tool, reasoning_tool, math_tool]

agent = initialize_agent(
    tools=tools,
    llm=llm,
    agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True,
    handle_parsing_errors=True,
)

# ---------------------- Chat Memory ----------------------
if "messages" not in st.session_state:
    st.session_state.messages = [
        {"role": "assistant", "content": "Hi! I'm your math & logic assistant. Ask me anything!"}
    ]

for msg in st.session_state.messages:
    st.chat_message(msg["role"]).write(msg["content"])

user_input = st.chat_input("Ask me a math or logic problem…")
if user_input:
    st.session_state.messages.append({"role": "user", "content": user_input})
    st.chat_message("user").write(user_input)

    with st.chat_message("assistant"):
        st_cb = StreamlitCallbackHandler(st.container(), expand_new_thoughts=False)
        try:
            answer = agent.run(user_input, callbacks=[st_cb])
        except Exception as e:
            answer = f"❌ Error: {e}"

        st.session_state.messages.append({"role": "assistant", "content": answer})
        st.write(answer)
