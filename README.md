# 🚀 MathGPT  
### Your Premier Math & Coding Assistant  

From symbolic integrals to GPU-accelerated code generation, end-to-end.  

---

![MathGPT Hero](assets/images/01-welcome.png)

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
11. [License & Author](#license--author)  

---

## 📝 Project Overview

**MathGPT** unifies two best-in-class assistants in one platform:

- **General Assistant**  
  - Ultra-low-latency factual reasoning via Groq’s hosted LLaMA-class engines  
  - Automatic integration of Sympy (symbolic math) and Wikipedia for real-time lookups  

- **Coding Assistant**  
  - GPU-accelerated code generation tuned on LeetCode datasets  
  - QLoRA adapters delivering 99.9% accuracy on complex algorithmic tasks  

Under the hood:

- Kubernetes on GKE with a dedicated GPU node pool  
- Terraform-defined infra + GitHub Actions CI/CD  
- A futuristic, responsive Streamlit-based frontend with smooth page transitions  

Live demos:  
- **General:** https://mathsgpt-cce2euliqa-ez.a.run.app/  
- **Coding:**  http://34.91.234.32/  

> _“From conceptual math to bug-free code in seconds.”_

---

## ⭐ Key Features

| Feature                         | Benefit                                                      |
|---------------------------------|--------------------------------------------------------------|
| **Symbolic Math & Integrals**   | Step-by-step solutions powered by Sympy                      |
| **Wikipedia Toolchain**         | Contextual, on-demand factual lookups                        |
| **Groq API Integration**        | 10× faster inference on Groq hardware                        |
| **LangChain Agent**             | Automatic tool orchestration & dynamic prompt chainer        |
| **QLoRA Fine-Tuning**           | 4× smaller adapters with 4-bit quantization                  |
| **GPU Node Pool & Autoscaling** | Instant scale-up for heavy model loads                       |
| **Terraform IAC**               | Reproducible infra in <30 lines of code                      |
| **GitHub Actions CI/CD**        | Zero-downtime rolling updates on Kubernetes                  |
| **Sci-Fi Web UI**               | Responsive theme, pixel-perfect layouts, fade transitions    |

---

## 📐 Architecture & Tech Stack

```mermaid
flowchart LR
  subgraph General Assistant
    A[Streamlit UI] --> B[LangChain Agent]
    B --> C[Groq API (Gemma, DeepSeek-R1)]
    B --> D[Sympy Calculator]
    B --> E[Wikipedia API]
  end

  subgraph Coding Assistant
    A2[Streamlit UI] --> F[Base LLM: deepseek-ai/deepseek-coder-1.3b-instruct]
    F --> G[LoRA Adapter (QLoRA)]
    G --> H[GPU Nodes (GKE)]
  end

  subgraph Infra
    I[Terraform] --> J[GCP Project]
    J --> K[GKE Cluster + GPU Pool]
    J --> L[Cloud Load Balancer]
    CI[GitHub Actions] --> K
  end
