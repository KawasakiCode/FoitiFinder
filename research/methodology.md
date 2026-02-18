# Face Scoring Methodology

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