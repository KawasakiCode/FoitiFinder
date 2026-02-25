import os
import joblib
from pathlib import Path
from deepface import DeepFace

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
    except Exception as e:
        rating_model = None

    if rating_model is None:
        return None
    
    if not os.path.exists(image_path):
        return None
    
    try:
        #Run the image through facenet to get the embeddings (128d vector)
        #Use MTCNN for face detection
        embedding_objs = DeepFace.represent(  
            img_path = image_path,
            model_name = 'Facenet',
            enforce_detection = True,
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
