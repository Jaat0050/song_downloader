from flask import jsonify

def make_error(code: str, message: str, status_code: int = 400):
    return jsonify({
        "success": False,
        "error": {
            "code": code,
            "message": message
        }
    }), status_code
