# Executes an instance segmentation of tree crowns for input pictures
from gluoncv import model_zoo, data, utils
import mxnet as mx
mx.test_utils.list_gpus()
import numpy as np

from PIL import Image
import sys
from os import listdir
from os import path
import os
print(os.getcwd())

wd = sys.argv[1]
folder_source = path.join(wd, 'result')
folder_target = path.join(wd,'result')

included_extensions = [ 'jpg',"png"]
ctx = [mx.gpu()] if mx.test_utils.list_gpus() else [mx.cpu()]

if __name__== "__main__":
    net = model_zoo.get_model('mask_rcnn_resnet50_v1b_coco', pretrained=True, root=path.join(wd,'src/Mask_R-CNN'), ctx=ctx)
    net.load_parameters(path.join(wd, "src/Mask_R-CNN/mask_rcnn_resnet50_v1b_coco_best.params"), ctx=ctx)
    net.collect_params().reset_ctx(ctx)

    folders_source = listdir(folder_source)

    for folder in folders_source:
        print("Starting folder: " + folder)
        folder_path = path.join(folder_source, folder, "pics")
        folder_out = path.join(folder_target, folder, "masks")
        os.makedirs(folder_out, exist_ok=True)

        files = [fn for fn in listdir(folder_path)
                if any(fn.endswith(ext) for ext in included_extensions)]

        if path.exists(folder_out):
            files_done = [fn for fn in listdir(folder_out)
                if any(fn.endswith(ext) for ext in included_extensions)]

            pics_done = set([i.split("_", 1)[1].split("_", 1)[0] for i in files_done])
        else:
            pics_done= []

        for file in files:
            pic_id = file.split("_", 1)[1].split(".jpg", 1)[0]
            if pic_id in pics_done:
                print(pic_id + " done")
            else:
                try:
                    im_fname = utils.download(r'temp.jpg',
                                path= path.join(folder_path + '/pic_' + str(pic_id) + '.jpg'))

                    x, orig_img = data.transforms.presets.rcnn.load_test(im_fname, short=500)

                    ids, scores, bboxes, masks = [xx[0].asnumpy() for xx in net(x.as_in_context(ctx[0]))]

                    width, height = orig_img.shape[1], orig_img.shape[0]
                    masks = utils.viz.expand_mask(masks, bboxes, (width, height), scores)

                    for i in range(len(masks)):
                        mask_img = Image.fromarray(masks[i])
                        img_name = path.join(folder_out + '/mask_' + str(pic_id) + "_" + str(i) + ".png")
                        mask_img.save(img_name)
                except Exception:
                    print(file + " failed")



