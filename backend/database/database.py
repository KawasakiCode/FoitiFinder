from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import os

#THE .env IS FOUND RELATIVE TO THIS FILE, not to whoever is calling. A bare
#load_dotenv() searches upwards from the WORKING directory, so it found
#backend/.env when uvicorn was started from backend/ and found nothing at all
#when pytest ran from the repo root - leaving DATABASE_URL unset and
#create_engine(None) as the error, which says nothing about the real cause.
#
#A variable already in the environment still wins: load_dotenv does not
#override, which is what lets the test suite point this at a test database and
#what let a stray shell variable serve production on localhost.
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, ".env"))

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

#Neon suspends its compute after a few minutes of inactivity, which silently
#kills every pooled connection. Without pool_pre_ping the next request checks
#out a dead socket and dies with "SSL connection has been closed unexpectedly".
#pre_ping cheaply validates a connection before use and transparently reopens
#it; recycle drops connections older than the idle window before they go stale.
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=300,
)

SessionLocal  = sessionmaker(autocommit = False, autoflush= False, bind = engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()