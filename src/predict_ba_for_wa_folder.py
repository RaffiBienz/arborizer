from gluoncv import model_zoo, data, utils
import mxnet as mx
from mxnet import init, nd
import numpy as np
import sys
from mxnet.gluon import nn
from os import listdir

w = sys.argv[1]
wd_path = sys.argv[2]

folder_path = wd_path + r"result\\" + str(w) + r"\tree_masks"

file_pred = open(folder_path + r"\\" + r"predictions.txt","w")

if __name__== "__main__":

    included_extensions = [ 'png']
    files = [fn for fn in listdir(folder_path)
             if any(fn.endswith(ext) for ext in included_extensions)]


    ctx = [mx.cpu()]
    num_outputs=14

    model_name = 'mobilenet1.0'
    net = model_zoo.get_model(model_name, pretrained = True, root = wd_path + r'src\mobilenet')
    with net.name_scope():
        net.output = nn.Dense(num_outputs)
    net.output.initialize(init.Xavier(), ctx=ctx)
    net.collect_params().reset_ctx(ctx)
    net.hybridize()
    net.load_parameters(wd_path + r'src\mobilenet\mobilenet1.0_train_set_ba_19102020.params', ctx=ctx)

    for file in files:
        try:
            x, orig_img = data.transforms.presets.rcnn.load_test(folder_path + r"\\" + file, short=110)
            pred = net(x)
            ind = nd.topk(pred, k=1)[0].astype('int')
            prob = nd.softmax(pred)[0][ind].asscalar()
            #result = nd.argmax(net(x), axis=1)
            id = file.split("_", 1)[1].split(".png", 1)[0]
            file_pred.write(id + " " + str(ind.asscalar()) + " " + str(prob) + "\n")
        except Exception:
            print(file)

    file_pred.close()
