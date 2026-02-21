import json
from pathlib import Path

def convert(coco, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    data = json.load(open(coco))
    images = {i["id"]: i for i in data["images"]}

    for ann in data["annotations"]:
        img = images[ann["image_id"]]
        w,h = img["width"], img["height"]
        x,y,bw,bh = ann["bbox"]
        xc = (x+bw/2)/w
        yc = (y+bh/2)/h
        bw/=w
        bh/=h
        label = out_dir / f"{Path(img['file_name']).stem}.txt"
        with open(label,"a") as f:
            f.write(f"{ann['category_id']} {xc} {yc} {bw} {bh}\n")
