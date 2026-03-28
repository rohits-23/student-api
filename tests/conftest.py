import pytest

from app import create_app
from app.extensions import db as _db


@pytest.fixture(scope="session")
def app():
    """Create a Flask application configured for the test session."""
    flask_app = create_app("testing")
    flask_app.config.update(
        SQLALCHEMY_DATABASE_URI="sqlite:///:memory:",
        TESTING=True,
    )
    with flask_app.app_context():
        _db.create_all()
        yield flask_app
        _db.drop_all()


@pytest.fixture(scope="function")
def client(app):
    """Provide a test client for each test function."""
    with app.test_client() as test_client:
        yield test_client


@pytest.fixture(scope="function", autouse=True)
def clean_tables(app):
    """Wipe all rows before each test to guarantee isolation."""
    yield
    with app.app_context():
        for table in reversed(_db.metadata.sorted_tables):
            _db.session.execute(table.delete())
        _db.session.commit()
