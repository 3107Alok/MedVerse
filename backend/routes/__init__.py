from flask import Blueprint, request, jsonify
from models import UserModel
from firebase_config import verify_token
from db import get_db

db = get_db()

import os
from werkzeug.utils import secure_filename
from firebase_admin import messaging, firestore

def send_fcm_notification(recipient_uid, title, body, type_str):
    try:
        firestore_db = firestore.client()
        notif_ref = firestore_db.collection('users').document(recipient_uid).collection('notifications').document()
        notification_id = notif_ref.id
        
        notif_data = {
            'title': title,
            'message': body,
            'type': type_str,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'isRead': False
        }
        notif_ref.set(notif_data)
        
        recipient_doc = firestore_db.collection('users').document(recipient_uid).get()
        if recipient_doc.exists:
            fcm_token = recipient_doc.to_dict().get('fcmToken')
            if fcm_token:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                    ),
                    token=fcm_token,
                )
                messaging.send(message)
    except Exception as e:
        print(f"Non-blocking FCM/Notification history failure: {e}")

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg'}

from functools import wraps

api_blueprint = Blueprint('api', __name__)

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            token = request.args.get('token')
        if not token:
            return jsonify({"error": "Token is missing"}), 401
        
        # Remove "Bearer " prefix if present
        if token.startswith('Bearer '):
            token = token[7:]
            
        decoded_token = verify_token(token)
        if not decoded_token:
            return jsonify({"error": "Invalid or expired token"}), 401
            
        # Ensure 'uid' is populated consistently (from user_id or sub)
        if 'uid' not in decoded_token:
            decoded_token['uid'] = decoded_token.get('user_id') or decoded_token.get('sub')
            
        # Add decoded user info to request
        request.user = decoded_token
        
        # Log the authenticated user details for auditing/debugging
        print("AUTHENTICATED USER:", request.user)
        print("USER TYPE:", type(request.user))
        
        return f(*args, **kwargs)
    return decorated

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@api_blueprint.route('/register', methods=['POST'])
def register():
    try:
        # Check if this is a multipart request (with files) or a simple JSON
        if request.content_type.startswith('multipart/form-data'):
            data = request.form.to_dict()
            files = request.files
        else:
            data = request.json
            files = {}

        # Basic validation
        required_fields = ['uid', 'email', 'name', 'role', 'status']
        if not all(field in data for field in required_fields):
            return jsonify({"error": "Missing required fields"}), 400
        
        # Handle certificate upload for doctors
        if data.get('role') == 'doctor' and 'certificate' in files:
            file = files['certificate']
            if file and allowed_file(file.filename):
                filename = secure_filename(f"{data['uid']}_{file.filename}")
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                file.save(file_path)
                data['certificate_path'] = file_path

        UserModel.create_user(data)
        return jsonify({"message": "User registered successfully", "status": "success"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/user/<uid>', methods=['GET'])
@token_required
def get_user(uid):
    try:
        user = UserModel.get_user_by_uid(uid)
        if user:
            return jsonify(user), 200
        return jsonify({"error": "User not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/doctors/pending', methods=['GET'])
@token_required
def get_pending_doctors():
    # Only allow admins to see pending doctors
    if request.user.get('role') != 'admin' and UserModel.get_user_by_uid(request.user['uid']).get('role') != 'admin':
         # Note: Decoded token might not have 'role' if it's not a custom claim. 
         # We should check DB for the role associated with the UID.
         user = UserModel.get_user_by_uid(request.user['uid'])
         if not user or user.get('role') != 'admin':
             return jsonify({"error": "Unauthorized"}), 403
             
    try:
        doctors = UserModel.get_pending_doctors()
        return jsonify(doctors), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/doctors/verify', methods=['POST'])
@token_required
def verify_doctor():
    try:
        user = UserModel.get_user_by_uid(request.user['uid'])
        if not user or user.get('role') != 'admin':
            return jsonify({"error": "Unauthorized"}), 403

        data = request.json
        uid = data.get('uid')
        status = data.get('status')
        
        db.users.update_one({"uid": uid}, {"$set": {"status": status}})
        
        try:
            firestore_db = firestore.client()
            is_approved = status.lower() == 'verified'
            firestore_db.collection('users').document(uid).update({
                'status': status.lower(),
                'verified': is_approved
            })
        except Exception as fe:
            print(f"Firestore user update error: {fe}")

        if status.lower() == 'verified':
            send_fcm_notification(
                recipient_uid=uid,
                title='Account Approved',
                body='Congratulations! Your Doctor account has been approved.',
                type_str='approval'
            )
        
        return jsonify({"message": f"Doctor status updated to {status}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/doctors', methods=['GET'])
def get_all_doctors():
    try:
        doctors = list(db.users.find({"role": "doctor", "status": "verified"}, {"_id": 0}))
        return jsonify(doctors), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/appointments/book', methods=['POST'])
@token_required
def book_appointment():
    try:
        data = request.json
        db.appointments.insert_one(data)
        
        try:
            fs_data = {k: v for k, v in data.items() if k != '_id'}
            firestore_db = firestore.client()
            fs_data['createdAt'] = firestore.SERVER_TIMESTAMP
            firestore_db.collection('appointments').add(fs_data)
        except Exception as fe:
            print(f"Firestore appointment insert error: {fe}")

        doctor_id = data.get('doctor_id')
        patient_name = data.get('patient_name', 'A patient')
        if doctor_id:
            send_fcm_notification(
                recipient_uid=doctor_id,
                title='New Appointment',
                body=f'New appointment request from {patient_name}.',
                type_str='new_appointment'
            )
            
        return jsonify({"message": "Appointment booked successfully"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/appointments/<uid>', methods=['GET'])
@token_required
def get_user_appointments(uid):
    try:
        # Check both patient_id and doctor_id
        appointments = list(db.appointments.find({"$or": [{"patient_id": uid}, {"doctor_id": uid}]}, {"_id": 0}))
        return jsonify(appointments), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/reminders', methods=['POST'])
@token_required
def add_reminder():
    try:
        data = request.json
        # {uid, medicine_name, frequency, times: []}
        db.reminders.insert_one(data)
        return jsonify({"message": "Reminder added successfully"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/reminders/<uid>', methods=['GET'])
@token_required
def get_reminders(uid):
    try:
        reminders = list(db.reminders.find({"uid": uid}, {"_id": 0}))
        return jsonify(reminders), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

from ai_engine import AIEngine

@api_blueprint.route('/chatbot', methods=['POST'])
def chatbot():
    try:
        data = request.json
        query = data.get('query', '')
        specialist, advice = AIEngine.map_symptoms_to_specialist(query)
        return jsonify({
            "specialist": specialist,
            "advice": advice,
            "can_book": True
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/ocr/prescription', methods=['POST'])
@token_required
def ocr_prescription():
    try:
        if 'image' not in request.files:
            return jsonify({"error": "No image uploaded"}), 400
            
        file = request.files['image']
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            file_path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(file_path)
            
            text = AIEngine.extract_text_from_image(file_path)
            medicines = AIEngine.extract_medicine_details(text)
            
            return jsonify({
                "extracted_text": text,
                "medicines": medicines
            }), 200
        return jsonify({"error": "Invalid file type"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/prescription/analyze', methods=['POST'])
def analyze_prescription_endpoint():
    file_path = None
    try:
        # 1. Validation: Verify if file is present
        if 'image' not in request.files:
            return jsonify({"error": "No image file uploaded"}), 400
            
        file = request.files['image']
        if not file or file.filename == '':
            return jsonify({"error": "Empty file uploaded"}), 400
            
        # 2. Validation: Check extensions (jpg, jpeg, png)
        filename = secure_filename(file.filename)
        ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
        if ext not in {'jpg', 'jpeg', 'png'}:
            return jsonify({"error": "Invalid file type. Only JPG, JPEG, and PNG images are allowed."}), 400
            
        # 3. Create absolute path for uploads folder to prevent CWD dependency issues
        base_dir = os.path.dirname(os.path.abspath(__file__))
        upload_dir = os.path.join(base_dir, UPLOAD_FOLDER)
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)
            
        file_path = os.path.join(upload_dir, filename)
        
        # 4. Save file temporarily
        file.save(file_path)
        
        # 5. Validation: Enforce max 10MB size limit
        file_size = os.path.getsize(file_path)
        if file_size > 10 * 1024 * 1024:
            return jsonify({"error": "File size exceeds the 10MB limit."}), 400
            
        # 6. Analyze the prescription using Gemini
        analysis_result = AIEngine.analyze_prescription(file_path)
        return jsonify(analysis_result), 200
        
    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400
    except Exception as e:
        return jsonify({"error": f"Internal server error: {str(e)}"}), 500
    finally:
        # 7. Delete temporary image immediately after processing
        if file_path and os.path.exists(file_path):
            try:
                os.remove(file_path)
            except Exception as cleanup_err:
                print(f"Error removing temporary file: {cleanup_err}")


@api_blueprint.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        if not data or 'message' not in data:
            return jsonify({"error": "Message is required"}), 400
            
        message = data.get('message', '').strip()
        if not message:
            return jsonify({"error": "Empty message uploaded"}), 400
            
        history = data.get('history', [])
        
        # Call Gemini AI
        reply = AIEngine.chat_with_ai(message, history)
        return jsonify({
            "success": True,
            "response": reply
        }), 200
        
    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400
    except Exception as e:
        return jsonify({"error": f"Gemini API failure: {str(e)}"}), 500

@api_blueprint.route('/appointments/update-status', methods=['POST'])
@token_required
def update_appointment_status():
    try:
        data = request.json
        appointment_id = data.get('appointmentId')
        status = data.get('status')
        
        firestore_db = firestore.client()
        doc_ref = firestore_db.collection('appointments').document(appointment_id)
        doc = doc_ref.get()
        if not doc.exists:
            return jsonify({"error": "Appointment not found"}), 404
            
        doc_data = doc.to_dict()
        doc_ref.update({'status': status.lower()})
        
        db.appointments.update_one({"id": appointment_id}, {"$set": {"status": status.lower()}})
        
        patient_id = doc_data.get('patient_id')
        doctor_name = doc_data.get('doctor_name', 'Doctor')
        if patient_id:
            if status.lower() == 'approved':
                send_fcm_notification(
                    recipient_uid=patient_id,
                    title='Appointment Accepted',
                    body=f'Your appointment with Dr. {doctor_name} has been accepted.',
                    type_str='appointment_accepted'
                )
            elif status.lower() == 'rejected':
                send_fcm_notification(
                    recipient_uid=patient_id,
                    title='Appointment Declined',
                    body=f'Your appointment with Dr. {doctor_name} was declined.',
                    type_str='appointment_declined'
                )
        return jsonify({"message": "Status updated successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/labs/verify', methods=['POST'])
@token_required
def verify_lab():
    try:
        user = UserModel.get_user_by_uid(request.user['uid'])
        if not user or user.get('role') != 'admin':
            return jsonify({"error": "Unauthorized"}), 403
            
        data = request.json
        uid = data.get('uid')
        status = data.get('status')
        is_approved = status.lower() == 'approved'
        
        firestore_db = firestore.client()
        firestore_db.collection('users').document(uid).update({
            'status': status.lower(),
            'verified': is_approved
        })
        firestore_db.collection('lab_profiles').document(uid).update({
            'status': status.lower(),
            'verified': is_approved
        })
        
        if status.lower() == 'approved':
            send_fcm_notification(
                recipient_uid=uid,
                title='Account Approved',
                body='Congratulations! Your Laboratory account has been approved.',
                type_str='approval'
            )
        return jsonify({"message": f"Lab status updated to {status}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/lab-bookings/book', methods=['POST'])
@token_required
def book_lab_test():
    try:
        data = request.json
        firestore_db = firestore.client()
        booking_id = data.get('bookingId')
        if not booking_id:
            doc_ref = firestore_db.collection('lab_bookings').document()
            booking_id = doc_ref.id
            data['bookingId'] = booking_id
        else:
            doc_ref = firestore_db.collection('lab_bookings').document(booking_id)
            
        data['createdAt'] = firestore.SERVER_TIMESTAMP
        doc_ref.set(data)
        
        lab_id = data.get('labId')
        patient_name = data.get('patientName', 'A patient')
        if lab_id:
            send_fcm_notification(
                recipient_uid=lab_id,
                title='New Lab Booking',
                body=f'New lab booking request from {patient_name}.',
                type_str='new_lab_booking'
            )
        return jsonify({"message": "Lab booking successfully created", "bookingId": booking_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@api_blueprint.route('/lab-bookings/update-status', methods=['POST'])
@token_required
def update_lab_booking_status():
    try:
        data = request.json
        booking_id = data.get('bookingId')
        status = data.get('status')
        
        firestore_db = firestore.client()
        doc_ref = firestore_db.collection('lab_bookings').document(booking_id)
        doc = doc_ref.get()
        if not doc.exists:
            return jsonify({"error": "Lab booking not found"}), 404
            
        doc_data = doc.to_dict()
        doc_ref.update({'status': status.lower()})
        
        patient_uid = doc_data.get('uid')
        lab_name = doc_data.get('labName', 'Laboratory')
        if patient_uid:
            if status.lower() == 'approved':
                send_fcm_notification(
                    recipient_uid=patient_uid,
                    title='Lab Booking Accepted',
                    body=f'Your lab booking at {lab_name} has been accepted.',
                    type_str='lab_booking_accepted'
                )
            elif status.lower() == 'rejected':
                send_fcm_notification(
                    recipient_uid=patient_uid,
                    title='Lab Booking Declined',
                    body=f'Your lab booking at {lab_name} was declined.',
                    type_str='lab_booking_declined'
                )
        return jsonify({"message": "Lab booking status updated successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

