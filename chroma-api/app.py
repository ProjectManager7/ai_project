from flask import Flask
from routes import app1

def create_app():
    app = Flask(__name__)
    app.register_blueprint(app1)
    return app