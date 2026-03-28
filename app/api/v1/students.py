import logging

from flask import jsonify, request

from . import api_v1_bp
from ...extensions import db
from ...models.student import Student

logger = logging.getLogger(__name__)


@api_v1_bp.route("/students", methods=["GET"])
def get_students():
    logger.info("GET /students — fetching all students")
    students = Student.query.all()
    return jsonify({"data": [s.to_dict() for s in students], "count": len(students)}), 200


@api_v1_bp.route("/students/<int:student_id>", methods=["GET"])
def get_student(student_id: int):
    logger.info("GET /students/%d", student_id)
    student = db.session.get(Student, student_id)
    if student is None:
        logger.warning("GET /students/%d — not found", student_id)
        return jsonify({"error": f"Student with id={student_id} not found"}), 404
    return jsonify({"data": student.to_dict()}), 200


@api_v1_bp.route("/students", methods=["POST"])
def create_student():
    payload = request.get_json(silent=True)
    if not payload:
        logger.warning("POST /students — missing or invalid JSON body")
        return jsonify({"error": "Request body must be valid JSON"}), 400

    missing = [f for f in ("name", "email") if f not in payload]
    if missing:
        logger.warning("POST /students — missing required fields: %s", missing)
        return jsonify({"error": f"Missing required fields: {missing}"}), 400

    if Student.query.filter_by(email=payload["email"]).first():
        logger.warning("POST /students — duplicate email: %s", payload["email"])
        return jsonify({"error": "A student with this email already exists"}), 409

    student = Student(
        name=payload["name"],
        email=payload["email"],
        age=payload.get("age"),
        grade=payload.get("grade"),
    )
    db.session.add(student)
    db.session.commit()
    logger.info("POST /students — created student id=%d", student.id)
    return jsonify({"data": student.to_dict(), "message": "Student created successfully"}), 201


@api_v1_bp.route("/students/<int:student_id>", methods=["PUT"])
def update_student(student_id: int):
    student = db.session.get(Student, student_id)
    if student is None:
        logger.warning("PUT /students/%d — not found", student_id)
        return jsonify({"error": f"Student with id={student_id} not found"}), 404

    payload = request.get_json(silent=True)
    if not payload:
        return jsonify({"error": "Request body must be valid JSON"}), 400

    if "email" in payload and payload["email"] != student.email:
        conflict = Student.query.filter(
            Student.email == payload["email"], Student.id != student_id
        ).first()
        if conflict:
            logger.warning("PUT /students/%d — email conflict: %s", student_id, payload["email"])
            return jsonify({"error": "Email is already in use by another student"}), 409

    for field in ("name", "email", "age", "grade"):
        if field in payload:
            setattr(student, field, payload[field])

    db.session.commit()
    logger.info("PUT /students/%d — updated successfully", student_id)
    return jsonify({"data": student.to_dict(), "message": "Student updated successfully"}), 200


@api_v1_bp.route("/students/<int:student_id>", methods=["DELETE"])
def delete_student(student_id: int):
    student = db.session.get(Student, student_id)
    if student is None:
        logger.warning("DELETE /students/%d — not found", student_id)
        return jsonify({"error": f"Student with id={student_id} not found"}), 404

    db.session.delete(student)
    db.session.commit()
    logger.info("DELETE /students/%d — deleted successfully", student_id)
    return jsonify({"message": "Student deleted successfully"}), 200
