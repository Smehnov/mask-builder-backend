from typing import Optional, List
from fastapi import FastAPI, File, UploadFile
from pydantic import BaseModel


class UserInfo(BaseModel):
    vk_id: int
    token: str


class Answer(BaseModel):
    answer_text: str
    answer_background: str


class RandomMask(BaseModel):
    question_text: str
    question_background: str

    answers: List[Answer]


app = FastAPI()


@app.get("/make-mask/random-chooser")
async def read_item(user_id: int, mask_name: str, question: bytes = File(...), answers: List[bytes] = File(...), token: str = ""):
    return {
        "user_id": user_id,
        "token": token,
        "mask_name": mask_name,
        "question": question,
        "answers": answers,
    }



