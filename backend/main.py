from fastapi import FastAPI
import os
from dotenv import load_dotenv
from database import models
from database.database import engine

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

@app.get("/")
def read_root():
    secret = os.getenv("SECRET_KEY")
    return {"status": "online", "message": "FoitiFinder backend is running"}