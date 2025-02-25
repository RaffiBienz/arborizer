# Predicts tree species for all pictures in the target folder
import numpy as np
import os
import tensorflow as tf
from os import path
import sys


wd = sys.argv[1]
PATH = path.join(wd, 'result')

model = tf.keras.models.load_model(path.join(wd,'src/MobileNetV2/202410150110model_best_0.81_aaa.keras'))

dirs = [item for item in os.listdir(PATH) if os.path.isdir(path.join(PATH,item))]

path_prog = path.join(PATH,'progress.txt')
if path.exists(path_prog):
    file_prog = open(path_prog,'r')
    folders_done = file_prog.read().splitlines()
    file_prog.close()

    dirs_sel = []

    for dir in dirs:
        if not dir in folders_done:
            dirs_sel.append(dir)
else:
    dirs_sel = dirs

BATCH_SIZE = 32
IMG_SIZE = (160, 160)

n_dirs = len(dirs_sel)

included_extensions = ['png']

for id, dir in enumerate(dirs_sel):
    PATH_dir = path.join(PATH,dir,"tree_masks")
    file_names = [fn for fn in os.listdir(PATH_dir)
              if any(fn.endswith(ext) for ext in included_extensions)]

    if len(file_names) > 0:
        file_pred = open(path.join(PATH_dir,'predictions.txt'),'w')

        dataset = tf.keras.utils.image_dataset_from_directory(PATH_dir,
                                                            labels=None,
                                                            verbose=0,
                                                            shuffle=False,
                                                                    batch_size=BATCH_SIZE,
                                                                    image_size=IMG_SIZE)

        pred_oh = model.predict(dataset)

        for idx, pred in enumerate(pred_oh):
            pred_int = np.argmax (pred, axis = 0)
            file_path = dataset.file_paths[idx]
            ba_id = file_path.split("_")[-1].split(".png")[0]
            #print(ba_id + " " + str(pred_int) + " " + str(pred[pred_int]))
            file_pred.write(ba_id + " " + str(pred_int) + " " + str(pred[pred_int]) + "\n")

        file_pred.close()

        file_prog = open(path_prog,'a')
        file_prog.write(dir + "\n")
        file_prog.close()
    print(f'{id} / {n_dirs}')
