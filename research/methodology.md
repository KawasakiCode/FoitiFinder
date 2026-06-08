# Face Scoring Methodology

## Reproducing the model

The trained model (`backend/matchmaker/rating_model.pkl`) ships with the repo, so you only need this if you want to retrain it. Files referenced below live in this `research/` folder.

1. **Get the dataset.** Download the [SCUT-FBP5500 dataset](https://github.com/HCIILAB/SCUT-FBP5500-Database-Release). You need the face images and the `All_Ratings.xlsx` ratings file.
2. **Filter the ratings.** Put `All_Ratings.xlsx` next to [`filter_data.py`](filter_data.py) and run it (`python filter_data.py`). It keeps the ~1,500 Caucasian images and averages the 60 raters' scores, producing `clean_caucasian_averages.csv`. To include or switch to the Asian subset, change `startswith('C')` inside the script (see its comments).
3. **Train.** Open [`rating_model_train.ipynb`](rating_model_train.ipynb). Training is heavy (FaceNet embeddings via DeepFace/TensorFlow), so running it on **Google Colab** is recommended: zip the dataset images, upload the zip and `clean_caucasian_averages.csv` to Google Drive, and mount Drive from the notebook. The notebook installs its own dependencies in its first cells.
4. **Install the model.** The notebook outputs `rating_model.pkl`. Copy it to `backend/matchmaker/rating_model.pkl` to make the backend use your newly trained model.

## 1. Objective
To create a lightweight, privacy-focused facial attractiveness scoring system for a dating application, capable of running efficiently on a standard backend CPU.

## 2. Dataset Selection
* **Source:** SCUT-FBP5500 Dataset.
* **Filtering:** We utilized a subset of ~1,500 images labeled "Caucasian" to align with the initial target demographic of the application and reduce demographic noise.
* **Label Processing:** The raw 1-5 ratings from 60 raters were averaged and linearly scaled to a 1-10 range to provide more granular scores.

## 3. Model Architecture
We employed a **Transfer Learning** approach to overcome the small dataset size:

1.  **Feature Extraction (FaceNet):** * We used the pre-trained `InceptionResnetV1` (FaceNet) model.
    * This converts a face image into a **128-dimensional Euclidean embedding**.
    * *Why FaceNet?* It is robust to minor lighting/pose variations and requires no retraining for feature recognition.

2.  **Regression Head (Linear Regression):**
    * We trained a simple Linear Regression model on top of the 128-d embeddings.
    * *Why Linear Regression?*
        * **Prevent Overfitting:** With only 1,500 data points, a Neural Network would likely memorize the training data.
        * **Interpretability:** Linear weights allow us to see which features contribute to the score.
        * **Speed:** Inference is an $O(1)$ dot product operation.

## 4. Results
* **Mean Absolute Error (MAE):** 0.61 (on a 1-10 scale).
* **Inference Speed:** < 200ms per image (including face detection).

## 5. Limitations
* **Bias:** The model reflects the preferences of the original SCUT raters (Asian university students), potentially favoring specific aesthetic traits (neoteny).
* **Domain Shift:** Performance degrades on wide-angle selfie shots due to lens distortion compared to the telephoto lens used in the training set.

## Disclaimer: Educational Purposes Only

This AI scoring engine was built strictly for **educational and portfolio demonstration purposes**. It should *not* be taken seriously or used as a genuine measure of human attractiveness. 

If you test the model with your own photo, please be aware that the algorithm is **extremely sensitive** to the following factors:

* **Facial Orientation (Pose):** The model was trained on straight-facing, passport-style images. Tilted heads, profile shots, or looking away from the camera will severely artificially lower the score.
* **Photo Quality & Lighting:** Harsh shadows, poor lighting, or camera lens distortion (such as wide-angle selfie lenses making noses appear larger) will negatively skew the mathematical embedding.
* **Phenotype & Rater Bias:** The ground-truth data relies on a specific subset of the SCUT-FBP5500 dataset, meaning the model is hardcoded to the subjective, culturally-dependent biases of the original raters which were chinese college students so they gave harsher ratings to caucasian people.

**TL;DR:** The scoring mechanism is highly rigid. If you upload a photo and receive a low rating, blame the dataset variance and the camera angle, not your face!