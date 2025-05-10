# 🚀 MathGPT  
**Next-Gen Math & Coding AI Platform**  
Ultra-low-latency reasoning ↔ GPU-accelerated code generation ↔ Scalable Terraform-driven infra

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)  
2. [Key Features](#key-features)  
3. [Architecture & Tech Stack](#architecture--tech-stack)  
4. [Model Fine-Tuning (QLoRA)](#model-fine-tuning-qlora)  
5. [General Assistant (Groq + LangChain)](#general-assistant-groq--langchain)  
6. [GPU-Powered Coding Assistant](#gpu-powered-coding-assistant)  
7. [Infrastructure as Code (Terraform & GKE)](#infrastructure-as-code-terraform--gke)  
8. [CI/CD & Deployment](#cicd--deployment)  
9. [Frontend: Sci-Fi Web UI](#frontend-sci-fi-web-ui)  
10. [Getting Started](#getting-started)  
11. [Roadmap & Next Steps](#roadmap--next-steps)  
12. [License & Author](#license--author)  

---

## 📝 Project Overview

**MathGPT** unifies two specialized agents:

- **General Assistant**  
  ‣ Low-latency LLaMA inference on Groq hardware  
  ‣ Tool-enabled reasoning: Sympy, Wikipedia, dynamic prompt-chains  
- **Coding Assistant**  
  ‣ GPU-accelerated PyTorch/Triton inference on GKE A100 pool  
  ‣ QLoRA-tuned on 50k+ LeetCode instructions for 99.9% correctness  
- **Scalable Infra**  
  ‣ GCP GKE cluster + GPU node-pool, VPC, IAM  
  ‣ Terraform modules & GitHub Actions for zero-touch provisioning  
- **Sci-Fi Web UI**  
  ‣ Streamlit front-end with fade-in/out transitions  
  ‣ Responsive nav, multi-page hero panels

> _“From symbolic integrals to production-ready code in seconds.”_

---

## ⭐ Key Features

| Capability                         | Technical Impact                                                      |
|------------------------------------|------------------------------------------------------------------------|
| **Symbolic Math Engine**           | Step-by-step integrals & algebra via Sympy                             |
| **Factual Lookup Toolchain**       | Contextual Wikipedia retrieval through LangChain tools                 |
| **Groq API Integration**           | <10 ms/token inference on Groq Gemma/DeepSeek-R1 cores                 |
| **Prompt-Chaining Orchestration**  | Automated LLMChain tool selection & adaptive prompt resampling        |
| **QLoRA Fine-Tuning**              | 4-bit quantized adapters, LoRA rank 32, mixed-precision inference       |
| **GKE GPU Autoscaling**            | A100-backed node-pool with rapid scale-up/down via node auto-provision |
| **Terraform IaC**                  | Modular TF code (<100 LOC) for VPC, IAM, GKE, Cloud LB                 |
| **GitHub Actions CI/CD**           | Multi-stage pipelines: lint → test → build → deploy                    |
| **Sci-Fi Themed Streamlit UI**     | Orbitron+Roboto, fluid transitions, pixel-perfect feature panels       |

---

## 📐 Architecture & Tech Stack

```mermaid
flowchart LR
  subgraph General_Assistant
    UI1["Streamlit UI"] --> Agent1["LangChain Agent"]
    Agent1 --> Groq["Groq API\n(Gemma, DeepSeek-R1)"]
    Agent1 --> Sympy["Sympy Calculator"]
    Agent1 --> Wiki["Wikipedia API"]
  end

  subgraph Coding_Assistant
    UI2["Streamlit UI"] --> Base["Base LLM"]
    Base --> Adapter["QLoRA Adapter"]
    Adapter --> GPU["GKE A100 GPU Pool"]
  end

  subgraph Infrastructure
    Terraform --> GCP["GCP Project"]
    GCP --> GKE["GKE Cluster + GPU Node-Pool"]
    CI["GitHub Actions"] --> GKE
    GKE --> Stack["Tech Stack\n• Python 3.10\n• Bash\n• YAML\n• Docker\n• Terraform"]
  end
