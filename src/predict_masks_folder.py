from gluoncv import model_zoo, data, utils
import mxnet as mx
from PIL import Image
import sys
from os import listdir


folder_id= sys.argv[1]
wd = sys.argv[2]
folder_path = wd + r'result\\' + folder_id + r'\pics'
folder_target = wd + r'result\\' + folder_id + r'\masks'
included_extensions = [ 'jpg',"png"]
ctx=[mx.gpu(0)]

if __name__== "__main__":
    net = model_zoo.get_model('mask_rcnn_resnet50_v1b_coco', pretrained=True, root=wd + r'src\resnet', ctx=ctx)
    net.load_parameters(wd + r"src\resnet\mask_rcnn_resnet50_v1b_coco_best.params", ctx=ctx)
    net.collect_params().reset_ctx(ctx)

    files = [fn for fn in listdir(folder_path)
            if any(fn.endswith(ext) for ext in included_extensions)]

    files_done = [fn for fn in listdir(folder_target)
        if any(fn.endswith(ext) for ext in included_extensions)]
    
    pics_done = set([i.split("_", 1)[1].split("_", 1)[0] for i in files_done])
   

    for file in files:
        pic_id = file.split("_", 1)[1].split(".jpg", 1)[0]
        if pic_id in pics_done:
            print(pic_id + " done")
        else:
            #try:
                im_fname = utils.download(r'temp.jpg',
                            path= wd + 'result\\' + folder_id + r'\pics\\pic_' + pic_id + r'.jpg')

                x, orig_img = data.transforms.presets.rcnn.load_test(im_fname, short=500)

                ids, scores, bboxes, masks = [xx[0].asnumpy() for xx in net(x.as_in_context(ctx[0]))]

                # paint segmentation mask on images directly
                width, height = orig_img.shape[1], orig_img.shape[0]
                masks = utils.viz.expand_mask(masks, bboxes, (width, height), scores)
                # orig_img = utils.viz.plot_mask(orig_img, masks)

                for i in range(len(masks)):
                    # mask_sum = utils.viz.plot_mask(im_empty, masks)
                    mask_img = Image.fromarray(masks[i])
                    img_name = wd + 'result\\' + folder_id + r'\masks\mask_' + pic_id + "_" + str(i) + ".png"
                    mask_img.save(img_name)
            #except Exception:
            #   print(file + " failed")



