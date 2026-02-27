import os
import cv2
import joblib
from pathlib import Path
from deepface import DeepFace
import numpy as np

#Load the model
MODEL_PATH = Path(__file__).parent / 'rating_model.pkl'

def get_face_score(image_path: str):
    """
    Analyzes a single image
    Returns a float score (1.0 - 10.0) if a face is found
    Returns None if no face is found or if an error occurs
    """

    try: 
        rating_model = joblib.load(MODEL_PATH)
    except Exception:

        rating_model = None

    if rating_model is None:
        return None
    
    if not os.path.exists(image_path):
        return None
    
    try:
        #This block grabs the image the user uplaods and crops and rotates it so 
        #it's only a perfectly straight face
        face_objs = DeepFace.extract_faces(
            img_path=image_path,
            detector_backend='mtcnn', 
            enforce_detection=True,
            align=True
        )
        
        # Get the actual image array of the first face found
        # DeepFace returns it as a normalized float (0 to 1) in RGB format
        aligned_face_array = face_objs[0]["face"]
        
        # Convert from normalized (0-1) to standard (0-255) integers
        face_uint8 = (aligned_face_array * 255).astype(np.uint8)
        
        # Convert from RGB (DeepFace) to BGR (OpenCV) so colors look right
        face_bgr = cv2.cvtColor(face_uint8, cv2.COLOR_RGB2BGR)

        #Run the image through facenet to get the embeddings (128d vector)
        #Use MTCNN for face detection
        embedding_objs = DeepFace.represent(  
            img_path = face_bgr,
            model_name = 'Facenet',
            enforce_detection = True,
            align = True,
            detector_backend= "mtcnn"
        )

        face_vector = embedding_objs[0]["embedding"]

        #Calculate the score
        prediction = rating_model.predict([face_vector])
        raw_score = prediction[0]

        #Ensure the score is between allowed range
        final_score = max(1.0, min(10.0, float(raw_score)))
        return round(final_score, 2)
    except ValueError:
        #If no face detected DeepFace throws a value error
        return None
    except Exception:
        return None