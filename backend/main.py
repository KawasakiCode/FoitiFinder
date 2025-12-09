from fastapi import FastAPI
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

@app.get("/")
def read_root():
    secret = os.getenv("SECRET_KEY")
    return {"status": "online", "message": "FoitiFinder backend is running", 
    "envcheck": f"env variable: {secret}"}