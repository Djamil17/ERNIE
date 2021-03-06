setwd('~/Desktop/Fig1')
library(data.table); library(dplyr); library(ggplot2)
rm(list=ls())
metab95_x4 <- fread('metab95_x4.csv')
metab_d95_x4 <- fread('metab_d95_x4.csv')
metab_d95_x4 <- metab_d95_x4 %>% mutate(bg='metab_wos')
metab95_x4 <- metab95_x4 %>% mutate(bg='metab95')
metab <- rbind(metab95_x4,metab_d95_x4)
#metab <- metab %>% mutate(set='metab')

imm95_x4 <- fread('imm95_x4.csv')
imm_d95_x4 <- fread('imm_d95_x4.csv')
imm95_x4 <- imm95_x4 %>% mutate(bg='imm95')
imm_d95_x4 <- imm_d95_x4 %>% mutate(bg='imm_wos')
imm <- rbind(imm95_x4,imm_d95_x4)
#imm <- imm %>% mutate(set='imm')

imm_metab <- rbind(imm,metab)
imm_metab$bg <- factor(imm_metab$bg,levels=c("imm95","metab95","imm_wos","metab_wos"))
imm_metab$class <- factor(imm_metab$class,levels=c('top1','top2','top3','top4','top5',
'top6','top7','top8','top9','top10','all'))
imm_metab$bg <- factor(imm_metab$bg,levels=c("imm95","imm_wos","metab95","metab_wos"))
pdf('fig2.pdf',height=5,width=7)
qplot(class,value,data=imm_metab,group=variable,color=variable,geom=c("point","line"),facets=.~bg,
# main="Effect of Background Network on Measuring Conventionality and Novelty\n imm95(21,000) & metab95(93,000) # publications respectively",
xlab="Citation Percentile Group",ylab="Percent of Publications") + theme(axis.text.x=element_text(angle=-65, hjust=0))
dev.off()
