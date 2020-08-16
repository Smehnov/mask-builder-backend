from typing import Optional, List
from fastapi import FastAPI, File, Form, UploadFile, Request
from pydantic import BaseModel
from zipfile import ZipFile
import os
from os.path import basename
from shutil import copyfile, copytree, make_archive
from PIL import Image

app = FastAPI()


@app.post('/hello/')
async def hello_world(request: Request):
    print(await request.body())
    return {
        "hello": "world"
    }


@app.post("/make-mask/random-chooser")
async def make_mask(user_id: str = Form(...), name: str = Form(...), question: UploadFile = File(...),
                    answers: List[UploadFile] = File(...),
                    token: str = ""):
    # TODO verifying user

    mask_path = "./masks/" + user_id + "_" + name
    if not os.path.exists(mask_path):
        os.mkdir(mask_path)

    copyfile("./mask_templates/random_mask/main.as", mask_path + "/main.as")
    copyfile("./mask_templates/random_mask/mask.json", mask_path + "/mask.json")
    copyfile("./mask_templates/random_mask/Icon.png", mask_path + "/Icon.png")
    copytree("./mask_templates/random_mask/Scripts", mask_path + "/Scripts")
    copytree("./mask_templates/random_mask/Textures", mask_path + "/Textures")

    f = open(mask_path + "/Textures/Question.png", "wb")
    f.write(question.file.read())
    f.close()

    for i, file in enumerate(answers):
        # TODO Image extention changing
        filename = mask_path + "/Textures/Answers/Answer" + (str(i) if i != 0 else "") + ".png"
        f = open(filename, "wb")
        f.write(file.file.read())
        f.close()
        img = Image.open(filename)
        w, h = img.size
        IMAGE_WIDTH = 240
        if w > 240:
            IMAGE_WIDTH = 240
        elif w > 120:
            IMAGE_WIDTH = 120
        elif w > 60:
            IMAGE_WIDTH = 60
        else:
            IMAGE_WIDTH = 30

        new_h = int(IMAGE_WIDTH / w * h)
        img = img.resize((IMAGE_WIDTH, new_h if new_h % 2 == 0 else new_h - 1))
        img.save(filename)

    make_archive(mask_path, 'zip', mask_path)

    return {
        "user_id": user_id,
        "token": token,
        "name": name,
        "question_size": question.content_type,
        "answers_size": [file.content_type for file in answers]
    }
