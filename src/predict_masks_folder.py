from gluoncv import model_zoo, data, utils
import mxnet as mx
from PIL import Image
import sys
from os import listdir
from pathlib import Path



folder_id= sys.argv[1]
wd = Path("/root/arborizer")
folder_path = wd/Path('result')/folder_id/Path('pics')
folder_target = wd/Path('result')/folder_id/Path('masks')
included_extensions = [ 'jpg',"png"]
ctx=[mx.cpu(0)]

if __name__== "__main__":
    net = model_zoo.get_model('mask_rcnn_resnet50_v1b_coco', pretrained=True, root=str(wd/Path('src\resnet')), ctx=ctx)
    path_params = Path("/root/arborizer/src/resnet/mask_rcnn_resnet50_v1b_coco_best.params")
    print(path_params)
    net.load_parameters(str(path_params), ctx=ctx)
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
                path= str(wd/Path('result')/Path(folder_id)/Path('pics/pic_'+pic_id + '.jpg'))
                print("Path is {}".format(path))
                # im_fname = utils.download('temp.jpg', path=path)
                

                x, orig_img = data.transforms.presets.rcnn.load_test(path, short=500)

                ids, scores, bboxes, masks = [xx[0].asnumpy() for xx in net(x.as_in_context(ctx[0]))]

                # paint segmentation mask on images directly
                width, height = orig_img.shape[1], orig_img.shape[0]
                masks = utils.viz.expand_mask(masks, bboxes, (width, height), scores)
                # orig_img = utils.viz.plot_mask(orig_img, masks)

                for i in range(len(masks)):
                    # mask_sum = utils.viz.plot_mask(im_empty, masks)
                    mask_img = Image.fromarray(masks[i])
                    img_name = str(wd/Path('result')/folder_id/Path('masks/mask_'+ pic_id + "_" + str(i) + ".png"))
                    mask_img.save(img_name)
            #except Exception:
            #   print(file + " failed")



