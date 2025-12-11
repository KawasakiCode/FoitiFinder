from fastapi import FastAPI
from dotenv import load_dotenv
from database import models
from database.database import engine

models.Base.metadata.create_all(bind=engine)

load_dotenv()

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "online", "message": "FoitiFinder backend is running"}