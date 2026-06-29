import pytesseract
from PIL import Image
import os
import google.generativeai as genai
import json

# Ensure Tesseract path is set if necessary
# pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

class AIEngine:
    @staticmethod
    def extract_text_from_image(image_path):
        try:
            text = pytesseract.image_to_string(Image.open(image_path))
            return text
        except Exception as e:
            print(f"OCR Error: {e}")
            return ""

    @staticmethod
    def map_symptoms_to_specialist(query):
        query = query.lower()
        mapping = {
            "fever": "General Physician",
            "cough": "General Physician",
            "chest pain": "Cardiologist",
            "heart": "Cardiologist",
            "skin": "Dermatologist",
            "rash": "Dermatologist",
            "bone": "Orthopedic",
            "fracture": "Orthopedic",
            "eye": "Ophthalmologist",
            "vision": "Ophthalmologist",
            "child": "Pediatrician",
            "kid": "Pediatrician",
            "stress": "Psychiatrist",
            "anxiety": "Psychiatrist",
        }
        
        found_specialists = []
        for symptom, specialist in mapping.items():
            if symptom in query:
                found_specialists.append(specialist)
        
        if not found_specialists:
            return "General Physician", "Stay hydrated and rest. If symptoms persist, consult a doctor."
            
        advice = "Please consult the suggested specialist for a detailed examination."
        return found_specialists[0], advice

    @staticmethod
    def extract_medicine_details(text):
        # Very basic extraction for demo; real implementation would use NER
        lines = text.split('\n')
        medicines = [line.strip() for line in lines if len(line.strip()) > 5]
        return medicines[:5] # Return top 5 potential medicines

    @staticmethod
    def analyze_prescription(image_path):
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            return {
                "success": False,
                "message": "GEMINI_API_KEY not found in environment variables",
                "document_type": "Unknown Medical Document",
                "report_type": "",
                "confidence": 0.0,
                "patient_name": "",
                "doctor_name": "",
                "hospital": "",
                "date": "",
                "diagnosis": "",
                "medicines": [],
                "follow_up": "",
                "notes": "",
                "lab_results": [],
                "summary": "",
                "recommendation": "",
                "warnings": ""
            }
            
        genai.configure(api_key=api_key)
        
        # Configure model and generation settings
        generation_config = {
            "temperature": 0.2, # Deterministic setting to minimize randomness
            "top_p": 0.95,
            "top_k": 40,
            "max_output_tokens": 8192,
            "response_mime_type": "application/json",
        }
        
        system_prompt = (
            "You are an expert universal medical document analyzer and medical assistant (MedVerse AI).\n"
            "Analyze the uploaded medical document image.\n"
            "The image may be a Prescription, Laboratory Report, Medical Bill, Discharge Summary, or an Unknown Medical Document.\n\n"
            "Classification & Extraction Rules:\n"
            "1. First, automatically detect the document type. Set 'document_type' to one of: 'Prescription', 'Laboratory Report', 'Medical Bill', 'Discharge Summary', or 'Unknown Medical Document'.\n"
            "2. If it is a Prescription:\n"
            "   - Extract patient_name, doctor_name, hospital, date, diagnosis, follow_up, notes.\n"
            "   - Extract medicines as a list. For each medicine, extract: name, strength, dosage, frequency, duration, instruction.\n"
            "   - Generate a simple patient-friendly explanation of the prescription in the 'summary' field.\n"
            "   - Set 'report_type' to '' and 'lab_results' to [].\n"
            "3. If it is a Laboratory Report:\n"
            "   - Identify the specific report type (e.g. 'CBC', 'Blood Sugar', 'Lipid Profile', 'LFT', 'KFT', 'Thyroid', 'Vitamin B12', 'Vitamin D', 'Urine Test', 'ECG', 'X-Ray', 'Unknown Lab Report'). Return this in the 'report_type' field.\n"
            "   - Do NOT search for or invent medicines. Set 'medicines' to [].\n"
            "   - Extract all important test parameters. For each parameter, extract: parameter (Test Name), value, unit, reference_range.\n"
            "   - Compare each value with its reference range if available. Classify status as ONLY one of: 'Normal', 'High', 'Low', 'Borderline', 'Unknown'.\n"
            "   - The AI must behave like a smart Gen-Z health assistant instead of a robotic clinical reporter.\n"
            "   - The language for all summary, recommendations, warnings, and parameter explanations MUST be simple Hinglish (Roman Hindi + English). Avoid difficult medical terminology unless necessary.\n"
            "   - For every parameter, in the 'explanation' field, generate a VERY short, mobile-friendly explanation in Hinglish (e.g. 'Hemoglobin level slightly low lag raha hai, green veggies khao' or 'Value is within range, perfectly normal hai'). Do NOT write long paragraphs for parameter explanations.\n"
            "   - In the 'summary' field, write a simple overall summary of the report in Hinglish, maximum 4-5 lines, as if you are explaining it to a friend (e.g. 'Overall report dekhne par lag raha hai ki Hemoglobin thoda low hai, jo khoon ki kami ki taraf indicate kar sakta hai. Baaki values mostly normal hain. Panic karne ki zarurat nahi hai, but ek baar doctor se consult kar lena better rahega.').\n"
            "   - In the 'recommendation' field, generate maximum 4 short bulleted lifestyle suggestions in Hinglish (e.g. '• Iron-rich food add karo 🥬\n• Pani proper quantity me piyo 💧\n• Daily thoda walk ya exercise karo 🚶\n• Doctor ki advice follow karo ❤️').\n"
            "   - In the 'warnings' field, generate maximum 2 lines of friendly doctor advice in Hinglish (e.g. 'Agar weakness, chakkar ya unusual symptoms feel ho rahe hain to doctor se consult kar lo. Ye AI explanation sirf educational purpose ke liye hai.').\n"
            "   - The tone must be friendly, modern, calm, easy to understand, and human (no textbook or scary medical jargon).\n"
            "   - NEVER diagnose diseases. NEVER prescribe medicines. NEVER create panic or use scary wording.\n"
            "   - Use phrases like 'Ho sakta hai...', 'Generally...', 'Doctor se confirm karna best rahega.' instead of absolute diagnostic statements.\n"
            "4. If it is a Medical Bill:\n"
            "   - Extract: hospital, date.\n"
            "   - Extract total amount, major charges, medicines, tests, other charges.\n"
            "   - Generate a short summary of charges in the 'summary' field.\n"
            "   - Set 'report_type' to '', 'medicines' to [], and 'lab_results' to [].\n"
            "5. If it is a Discharge Summary:\n"
            "   - Extract: patient_name, hospital, date, diagnosis, follow_up.\n"
            "   - Extract treatment given, procedures, precautions, and follow-up advice.\n"
            "   - Extract prescribed discharge medicines into the 'medicines' list.\n"
            "   - Generate a simple explanation of the summary in the 'summary' field.\n"
            "   - Set 'report_type' to '' and 'lab_results' to [].\n"
            "6. If the image is unreadable or not a medical document:\n"
            "   - Set 'document_type' to 'Unknown Medical Document'.\n"
            "   - Set 'report_type' to ''.\n"
            "   - Mark unreadable fields as 'Unreadable' or empty values.\n"
            "   - Set 'success' to false and provide an error message in 'message'.\n\n"
            "General Rules:\n"
            "- NEVER hallucinate. Never invent medicines, patient/doctor names, diagnoses, laboratory values, or dates. If unreadable or not present, use empty strings or empty lists.\n"
            "- Estimate a confidence score from 0.0 to 1.0 (e.g. 0.95 = High confidence) reflecting how clear and readable the document is, and return it in 'confidence'.\n"
            "- You MUST return ONLY valid JSON matching this exact structure:\n"
            "{\n"
            '  "success": true,\n'
            '  "message": "",\n'
            '  "document_type": "",\n'
            '  "report_type": "",\n'
            '  "confidence": 0.95,\n'
            '  "patient_name": "",\n'
            '  "doctor_name": "",\n'
            '  "hospital": "",\n'
            '  "date": "",\n'
            '  "diagnosis": "",\n'
            '  "medicines": [\n'
            "    {\n"
            '      "name": "",\n'
            '      "strength": "",\n'
            '      "dosage": "",\n'
            '      "frequency": "",\n'
            '      "duration": "",\n'
            '      "instruction": ""\n'
            "    }\n"
            "  ],\n"
            '  "follow_up": "",\n'
            '  "notes": "",\n'
            '  "lab_results": [\n'
            "    {\n"
            '      "parameter": "",\n'
            '      "value": "",\n'
            '      "unit": "",\n'
            '      "reference_range": "",\n'
            '      "status": "",\n'
            '      "explanation": ""\n'
            "    }\n"
            "  ],\n"
            '  "summary": "",\n'
            '  "recommendation": "",\n'
            '  "warnings": ""\n'
            "}\n"
        )
        
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash",
            generation_config=generation_config,
            system_instruction=system_prompt
        )
        
        # Open and load the image
        try:
            img = Image.open(image_path)
        except Exception as e:
            return {
                "success": False,
                "message": f"Failed to open image: {str(e)}",
                "document_type": "Unknown Medical Document",
                "report_type": "",
                "confidence": 0.0,
                "patient_name": "",
                "doctor_name": "",
                "hospital": "",
                "date": "",
                "diagnosis": "",
                "medicines": [],
                "follow_up": "",
                "notes": "",
                "lab_results": [],
                "summary": "",
                "recommendation": "",
                "warnings": ""
            }
            
        # Call the API with error handling for network/timeouts
        try:
            response = model.generate_content(img)
            response_text = response.text.strip()
        except Exception as e:
            return {
                "success": False,
                "message": f"AI service error: {str(e)}",
                "document_type": "Unknown Medical Document",
                "report_type": "",
                "confidence": 0.0,
                "patient_name": "",
                "doctor_name": "",
                "hospital": "",
                "date": "",
                "diagnosis": "",
                "medicines": [],
                "follow_up": "",
                "notes": "",
                "lab_results": [],
                "summary": "",
                "recommendation": "",
                "warnings": ""
            }
        
        # Parse and validate the JSON response
        try:
            # Strip markdown block wrappers if present
            cleaned_text = response_text
            if cleaned_text.startswith("```json"):
                cleaned_text = cleaned_text[7:]
            if cleaned_text.endswith("```"):
                cleaned_text = cleaned_text[:-3]
            cleaned_text = cleaned_text.strip()
            
            result = json.loads(cleaned_text)
            
            # Strict validation: enforce presence of all required backward compatible keys
            required_keys = ["patient_name", "doctor_name", "hospital", "date", "diagnosis", "medicines", "follow_up", "notes"]
            for key in required_keys:
                if key not in result:
                    result[key] = "" if key != "medicines" else []
            
            # Enforce presence of new fields
            if "success" not in result:
                result["success"] = True
            if "document_type" not in result:
                result["document_type"] = "Unknown Medical Document"
            if "report_type" not in result:
                result["report_type"] = ""
            if "confidence" not in result:
                result["confidence"] = 0.0
            if "lab_results" not in result:
                result["lab_results"] = []
            if "summary" not in result:
                result["summary"] = ""
            if "recommendation" not in result:
                result["recommendation"] = ""
            if "warnings" not in result:
                result["warnings"] = ""
                
            return result
            
        except (json.JSONDecodeError, Exception) as parse_err:
            print(f"JSON Parsing/Validation Error: {parse_err}. Raw response was: {response_text}")
            return {
                "success": False,
                "message": "Unable to analyze the uploaded document.",
                "document_type": "Unknown Medical Document",
                "report_type": "",
                "confidence": 0.0,
                "patient_name": "",
                "doctor_name": "",
                "hospital": "",
                "date": "",
                "diagnosis": "",
                "medicines": [],
                "follow_up": "",
                "notes": "",
                "lab_results": [],
                "summary": "",
                "recommendation": "",
                "warnings": ""
            }

    @staticmethod
    def chat_with_ai(message, history=None):
        if history is None:
            history = []
            
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY not found in environment variables")
            
        genai.configure(api_key=api_key)
        
        # Limit history context to the last 10 messages
        history = history[-10:]
        
        # Format history to Gemini SDK role format
        formatted_history = []
        for msg in history:
            role = "user" if msg.get("isUser") else "model"
            text = msg.get("text", "")
            formatted_history.append({
                "role": role,
                "parts": [text]
            })
            
        system_prompt = (
            "You are MedVerse AI.\n"
            "You are a healthcare assistant.\n\n"
            "Rules:\n"
            "1. Answer only healthcare, wellness, medicines, nutrition, fitness and lifestyle related questions. If the user asks anything outside of these topics, politely decline to answer, stating you are a healthcare assistant.\n"
            "2. Never diagnose diseases.\n"
            "3. Never prescribe medicines.\n"
            "4. Never recommend prescription drugs.\n"
            "5. Never claim certainty.\n"
            "6. Explain in simple language.\n"
            "7. If symptoms are serious, advise the user to visit a doctor.\n"
            "8. If the user asks about emergencies like chest pain, difficulty breathing, heavy bleeding, stroke symptoms, unconsciousness, or poisoning, immediately recommend emergency medical care.\n"
            "9. Keep responses under 200 words unless explicitly requested.\n"
            "10. Be polite.\n"
            "11. Do not generate markdown. Return plain text only.\n\n"
            "In addition, support the following interactive explanations:\n"
            "- If the user asks about a medicine (e.g., 'What is Paracetamol?'), explain its: Uses, Common side effects, and General precautions.\n"
            "- If the user asks about symptoms (e.g., 'I have fever and headache'), suggest: Possible common causes, Home care tips, and Red flags, and remind them to 'Consult a doctor if symptoms persist.'\n"
        )
        
        generation_config = {
            "temperature": 0.3,
            "top_p": 0.95,
            "top_k": 40,
            "max_output_tokens": 1024,
        }
        
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash",
            generation_config=generation_config,
            system_instruction=system_prompt
        )
        
        # Initialize chat with formatted history list
        chat = model.start_chat(history=formatted_history)
        response = chat.send_message(message)
        return response.text.strip()


