import os
os.system("yolo task=detect mode=train model=yolov8m.pt data=processed/skin.yaml epochs=150")
