FROM python:3.8

COPY requirements.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt
RUN apt update && apt-get install -y r-base libgdal-dev libproj-dev libgeos++-dev libudunits2-dev

# install R packages
COPY src/install_packages.R /root/install_packages.R
RUN Rscript /root/install_packages.R

WORKDIR /root/
CMD /bin/bash