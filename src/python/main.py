from flask import Flask, render_template, request, session, redirect, url_for
import os
from quiz_utils import get_categories, get_subjects, get_random_keyword
from ai_utils import generate_question, evaluate_answer

app = Flask(
    __name__,
    static_folder=os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'static')),
    template_folder=os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'templates'))
)
app.secret_key = os.environ.get('SECRET_KEY', 'devops-quiz-secret-key')


# --- Helper function to reset session ---
def reset_session(full=True):
    """Clear session data. 
    full=True → reset everything 
    full=False → keep category, subject, difficulty"""
    if full:
        session.clear()
    else:
        # Keep the selection but reset question-related data
        session.pop('question', None)
        session.pop('answer', None)
        session.pop('keyword', None)
        session.pop('feedback', None)


# --- Main index page (select category/subject/difficulty) ---
@app.route('/', methods=["GET", "POST"])
def index():
    categories = get_categories()
    feedback = session.pop('feedback', None)  # Get and remove feedback from session

    if request.method == "POST":
        action = request.form.get("action")

        if action == "reset":
            reset_session(full=True)
            return redirect(url_for('index'))

        # Update session from form data
        if 'category' in request.form:
            new_category = request.form['category'] or None
            if new_category != session.get('selected_category'):
                # Reset subject when category changes
                session.pop('selected_subject', None)
            session['selected_category'] = new_category
        if 'subject' in request.form:
            session['selected_subject'] = request.form['subject'] or None
        if 'difficulty' in request.form:
            session['difficulty'] = request.form['difficulty'] or None

        if action == "generate":
            if not session.get("difficulty"):
                feedback = "Please select a difficulty before generating a question."
            elif session.get('selected_category') and session.get('selected_subject'):
                session['keyword'] = get_random_keyword(
                    session['selected_category'],
                    session['selected_subject']
                )
                session['question'] = generate_question(
                    session['selected_category'],
                    session['keyword'],
                    int(session['difficulty'])
                )
                return redirect(url_for('question_page'))

    subjects = get_subjects(session.get('selected_category')) if session.get('selected_category') else []

    return render_template(
        "index.html",
        categories=categories,
        subjects=subjects,
        selected_category=session.get('selected_category'),
        selected_subject=session.get('selected_subject'),
        difficulty=session.get('difficulty'),
        feedback=feedback
    )


# --- Question page (answer & feedback) ---
@app.route('/question', methods=["GET", "POST"])
def question_page():
    # Check if we have a question, if not redirect to index
    if not session.get('question'):
        return redirect(url_for('index'))
    
    feedback = None
    question = session.get('question')
    keyword = session.get('keyword')
    difficulty = session.get('difficulty')

    if request.method == "POST":
        action = request.form.get("action")
        answer = request.form.get("answer")

        if action == "submit":
            if not answer or not answer.strip():
                feedback = "Please enter an answer before submitting."
            else:
                feedback = evaluate_answer(question, answer, int(difficulty))
                # Store feedback in session to persist across page refreshes
                session['feedback'] = feedback

        elif action == "ask_again":
            reset_session(full=False)
            return redirect(url_for('index'))
            
        elif action == "reset":
            reset_session(full=True)
            return redirect(url_for('index'))
    
    # Get feedback from session if it exists (for both GET and POST requests)
    feedback = session.get('feedback', feedback)

    return render_template(
        "question.html",
        question=question,
        keyword=keyword,
        difficulty=difficulty,
        feedback=feedback
    )

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)