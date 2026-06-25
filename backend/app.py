from flask import Flask, jsonify
from flask_cors import CORS
from routes import api_blueprint
from firebase_config import initialize_firebase
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)
initialize_firebase()
app.register_blueprint(api_blueprint, url_prefix='/api')

@app.route('/')
def index():
    return jsonify({"message": "MediNexa Backend API is running", "status": "success"})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
