from openai import OpenAI
import os
import boto3

ssm = boto3.client('ssm')
response = ssm.get_parameter(Name='/devops-quiz/openai-api-key', WithDecryption=True)
api_key = response['Parameter']['Value']

def generate_question(category, keyword, difficulty):
    """Generate a question for a keyword and difficulty level."""
    difficulty_label = {
        1: "basic level",
        2: "intermediate level",
        3: "advanced level"
    }[difficulty]

    prompt = QUESTION_PROMPT[difficulty].format(
        keyword=keyword, 
        category=category,
        difficulty_label=difficulty_label
    )

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}]
    )
    return response.choices[0].message.content.strip()

def evaluate_answer(question, answer, difficulty):
    """Generate a response based on the question and answer."""
    difficulty_label = {
        1: "basic level",
        2: "intermediate level",
        3: "advanced level"
    }[difficulty]

    prompt = EVAL_PROMPT.format(
        question=question, 
        answer=answer,
        difficulty_label=difficulty_label
    )

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}]
    )
    return response.choices[0].message.content.strip()

QUESTION_PROMPT = {
    1: """You are a DevOps interviewer. Create a short basic question on "{category}" in relation to "{keyword}".
- 1 sentence (≤25 words), answer ≤3 sentences.
- Ask only 1 question. No answer.""",

    2: """You are a DevOps interviewer. Create a short intermediate question on "{category}" in relation to "{keyword}"
- 1 sentence (≤25 words), answer ≤3 sentences.
- Ask only 1 question. No answer.""",

    3: """You are a DevOps interviewer. Create a short advanced and creative question on "{category}" in relation to "{keyword}"
- 1 sentence (≤25 words), answer ≤3 sentences.
- Ask only 1 question. No answer."""
}

EVAL_PROMPT = """
You are a DevOps teacher.
I will give you an interview question and the user's answer.
The candidate's answer should be breif, ≤3 sentences.

The question difficulty: {difficulty_label}
Q: "{question}"
A: "{answer}"

Tasks:
1. Score 1-10 (10 = excellent).
2. Feedback:
   - 9-10: brief praise.
   - 6-8: what is missing,
   - ≤5: main gap + what to study.
3. ignore grammer - focus on the core purpose of the answer.
4. review based on the question difficulty.

Format:
Your score: <number>/10
feedback: <text>
"""