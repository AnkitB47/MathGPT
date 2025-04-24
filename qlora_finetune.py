import os, json, re
from glob import glob
from dotenv import load_dotenv
from datasets import load_dataset
from sklearn.model_selection import train_test_split
from transformers import (
    TrainingArguments, Trainer, AutoModelForCausalLM, AutoTokenizer,
    DataCollatorForLanguageModeling, BitsAndBytesConfig, EarlyStoppingCallback
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
import torch

# ---------------------- ENV + CACHE ----------------------
load_dotenv()
hf_token = os.getenv("HF_TOKEN")

os.environ["HF_HOME"] = "/mnt/d/.hf_cache"
os.environ["TRANSFORMERS_CACHE"] = "/mnt/d/.transformers_cache"
os.environ["HF_DATASETS_CACHE"] = "/mnt/d/.datasets_cache"

MODEL_PATH = "coding_agent_model/deepseek-ai--deepseek-coder-1.3b-instruct"
DATA_PATH = "LeetCodeDataset/data"
OUTPUT_DIR = "output/qlora-deepseek"

# ---------------------- LOAD + FILTER DATA ----------------------
train_files = sorted([
    f for f in glob(os.path.join(DATA_PATH, "*.jsonl"))
    if re.search(r"train\.jsonl$", f)
])
test_files = sorted([
    f for f in glob(os.path.join(DATA_PATH, "*.jsonl"))
    if re.search(r"test\.jsonl$", f)
])

print("📦 Train files used:", train_files)
print("📦 Test files used:", test_files)

def load_jsonl_files(files):
    data = []
    for path in files:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                try:
                    ex = json.loads(line.strip())
                    if "prompt" in ex and "response" in ex:
                        data.append({
                            "messages": [
                                {"role": "user", "content": ex["prompt"]},
                                {"role": "assistant", "content": ex["response"]}
                            ]
                        })
                except Exception as e:
                    print(f"⚠️ Skipping malformed line in {path}: {e}")
    return data

all_data = load_jsonl_files(train_files + test_files)
print(f"✅ Total examples loaded and formatted: {len(all_data)}")

train_data, eval_data = train_test_split(all_data, test_size=0.1, random_state=42)

train_path = os.path.join(DATA_PATH, "train_prepared.jsonl")
eval_path = os.path.join(DATA_PATH, "eval_prepared.jsonl")

with open(train_path, "w", encoding="utf-8") as f:
    for row in train_data:
        f.write(json.dumps(row) + "\n")
with open(eval_path, "w", encoding="utf-8") as f:
    for row in eval_data:
        f.write(json.dumps(row) + "\n")

train_dataset = load_dataset("json", data_files=train_path, split="train")
eval_dataset = load_dataset("json", data_files=eval_path, split="train")

# ---------------------- LOAD MODEL ----------------------
bnb_config = BitsAndBytesConfig(
    load_in_8bit=True,
    llm_int8_threshold=6.0,
    llm_int8_has_fp16_weight=False,
)

model = AutoModelForCausalLM.from_pretrained(
    MODEL_PATH,
    quantization_config=bnb_config,
    trust_remote_code=True,
    device_map="auto",
    torch_dtype=torch.float32,
)

model = prepare_model_for_kbit_training(model)
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, trust_remote_code=True)
tokenizer.pad_token = tokenizer.eos_token

# ---------------------- APPLY QLoRA ----------------------
lora_config = LoraConfig(
    r=8,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)
model = get_peft_model(model, lora_config)

# ---------------------- TOKENIZATION ----------------------
def format_and_tokenize(example):
    messages = example["messages"]
    prompt = "\n\n".join([f"### {m['role'].capitalize()}: {m['content']}" for m in messages])
    return tokenizer(prompt, truncation=True, padding="max_length", max_length=1024)

tokenized_train = train_dataset.map(format_and_tokenize, remove_columns=train_dataset.column_names)
tokenized_eval = eval_dataset.map(format_and_tokenize, remove_columns=eval_dataset.column_names)
data_collator = DataCollatorForLanguageModeling(tokenizer=tokenizer, mlm=False)

# ---------------------- TRAINING ARGS ----------------------
training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    num_train_epochs=3,  # Keep it conservative to avoid overfitting
    logging_steps=10,
    evaluation_strategy="steps",      # 👈 matches save_strategy
    eval_steps=100,
    save_strategy="steps",            # 👈 MUST MATCH eval strategy
    save_steps=100,
    save_total_limit=1,              # 👈 avoid disk bloat
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    greater_is_better=False,
    fp16=False,
    bf16=False,
    report_to="none"
)

trainer = Trainer(
    model=model,
    tokenizer=tokenizer,
    args=training_args,
    train_dataset=tokenized_train,
    eval_dataset=tokenized_eval,
    data_collator=data_collator,
    callbacks=[EarlyStoppingCallback(early_stopping_patience=2)]
)

trainer.train()

# ---------------------- SAVE FINAL ADAPTERS ----------------------
adapter_path = os.path.join(OUTPUT_DIR, "adapters")
model.save_pretrained(adapter_path)
tokenizer.save_pretrained(adapter_path)
print("✅ Fine-tuning complete and saved adapters at:", adapter_path)
