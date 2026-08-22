import logging
from flask import Flask
from flask_cors import CORS

from config import Config
from routes.info_route import info_bp
from routes.download_route import download_bp
from routes.progress_route import progress_bp
from routes.file_route import file_bp
from routes.job_route import job_bp
from routes.health_route import health_bp

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)

    # Register individual route blueprints
    app.register_blueprint(info_bp)
    app.register_blueprint(download_bp)
    app.register_blueprint(progress_bp)
    app.register_blueprint(file_bp)
    app.register_blueprint(job_bp)
    app.register_blueprint(health_bp)

    return app

app = create_app()

if __name__ == "__main__":
    app.run(host=Config.HOST, port=Config.PORT, debug=False)
