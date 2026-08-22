import os
import sys
import unittest
from unittest.mock import patch

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import app
from services.ytdlp_service import is_valid_url

class AppTestCase(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()
        self.client.testing = True

    def test_url_validation(self):
        self.assertTrue(is_valid_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        self.assertTrue(is_valid_url("https://youtu.be/dQw4w9WgXcQ"))
        self.assertFalse(is_valid_url("https://example.com/video"))
        self.assertFalse(is_valid_url("invalid-url"))

    def test_info_endpoint_invalid_url(self):
        response = self.client.post("/api/audio/info", json={"url": "https://invalid.domain/test"})
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertFalse(data["success"])
        self.assertEqual(data["error"]["code"], "UNSUPPORTED_URL")

    def test_info_endpoint_missing_url(self):
        response = self.client.post("/api/audio/info", json={})
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertFalse(data["success"])
        self.assertEqual(data["error"]["code"], "INVALID_URL")

    @patch("services.ytdlp_service.YtDlpService.get_info")
    def test_info_endpoint_success(self, mock_get_info):
        mock_get_info.return_value = {
            "id": "test_id",
            "title": "Test Song",
            "artist": "Test Artist",
            "duration": 180,
            "thumbnail": "https://example.com/thumb.jpg",
            "webpage_url": "https://www.youtube.com/watch?v=test_id",
            "audio_formats": []
        }
        response = self.client.post("/api/audio/info", json={"url": "https://www.youtube.com/watch?v=test_id"})
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["title"], "Test Song")

    def test_progress_endpoint_job_not_found(self):
        response = self.client.get("/api/audio/progress/nonexistent-id")
        self.assertEqual(response.status_code, 404)
        data = response.get_json()
        self.assertFalse(data["success"])

    def test_file_endpoint_job_not_found(self):
        response = self.client.get("/api/audio/file/nonexistent-id")
        self.assertEqual(response.status_code, 404)
        data = response.get_json()
        self.assertFalse(data["success"])

    def test_delete_endpoint_job_not_found(self):
        response = self.client.delete("/api/audio/job/nonexistent-id")
        self.assertEqual(response.status_code, 404)
        data = response.get_json()
        self.assertFalse(data["success"])

if __name__ == "__main__":
    unittest.main()
