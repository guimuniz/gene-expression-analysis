library(Biobase)
library(GEOquery)
library(limma)
library(ggplot2)
library(affy)
library(preprocessCore)


# getting data
gSet <- getGEO("GSE40392", GSEMatrix =TRUE)
geneSignature <- getGEO("GPL6244", destdir=".")
gene <- data.frame(Table(geneSignature))
gSet <- gSet[[1]]
data <- exprs(gSet)
data.anno <- pData(gSet)


# sorting into groups (environmental and occupational)
grupo <- levels(data.anno$characteristics_ch1.1)
grupos = NULL
for(i in 1:length(grupo))
{
  grupos[i] <- dimnames(data.anno[data.anno$characteristics_ch1.1  == grupo[i], ])[1]
}

data <- data[, c(grupos[[1]], grupos[[2]]) ]


# amount of NA
table(is.na(data))


# plot environmental exposure vs Occupational exposure
vs <- matrix(nrow = dim(data)[1], ncol = 2)
for(i in 1:dim(data)[1])
{
    vs[i, 1] <- mean(data[i,grupos[[1]]])
    vs[i, 2] <- mean(data[i,grupos[[2]]])
}
plot(vs,xlab = "Environmental", ylab= "Occupational", main="Environmental exposure vs. Occupational exposure")
lines(lowess(vs), col = 2,lwd=2)


# coefficient of variance X mean
data.mean <- apply(data,1,mean)
data.sd <- apply(data,1,sd)
data.cv <- data.sd/data.mean
plot(data.mean, data.cv,main="CV vs. Média", xlab="Média", ylab="CV", col='red4', cex=0.5)


# normalization
ma.plot( rowMeans(log2(data[])), log2(data[, 1])-log2(data[, 2]), cex=1 )
dat.norm <- normalize.quantiles(data)
rownames(dat.norm) = rownames(data)
colnames(dat.norm) = colnames(data)
ma.plot( rowMeans(log2(dat.norm)), log2(dat.norm[, 1])-log2(dat.norm[, 2]), cex=1 )


# dendrogram
plot(hclust(dist(t(dat.norm))),main = "Dendograma");


# PCA
pca = prcomp(t(dat.norm))
col.groups = c(rep("red1", 9) , rep("red4", 9))
plot(pca$x[, 1:2], pch = 20, col = col.groups,
     main = "PCA - Environmental exposure group e Occupational exposure group",
     xlab = paste0("PC1 ", prettyNum(summary(pca)$importance[2,1]*100, digits = 2), "%"),
     ylab = paste0("PC2 ",prettyNum(summary(pca)$importance[2,2]*100, digits = 2 ), "%"))


# supervised analysis
my.t.test.p.value <- function(...) {
  obj<-try(t.test(...), silent=TRUE)
  if (is(obj, "try-error")) return(NA) else return(obj$p.value)
}
pval = apply(data,1,function(x) {my.t.test.p.value(x[colnames(data)[1:9]],x[colnames(data)[10:18]])})

dat1 = as.data.frame(data)
dat1$pval = pval
dat1$p.adj = p.adjust(dat1$pval, method = "BH")
dat1$meanEnv = apply(data[, 1:9], 1, mean, na.rm = T)
dat1$meanOcc = apply(data[, 10:18], 1, mean, na.rm = T)
dat1$FC = dat1$meanEnv - dat1$meanOcc
dat1$STATUS = "NOT.SIG"
dat1[dat1$p.adj < 0.05 & dat1$FC < 0 ,]$STATUS = "Down"
dat1[dat1$p.adj < 0.05 & dat1$FC > 0 , ]$STATUS = "Up"


# volcano plot
library(ggplot2)
ggplot(dat1, aes(x = FC, y = -log10(p.adj))) +
  geom_point(aes(color = STATUS), cex = 1.45) +
  scale_color_manual(values = c("SpringGreen4", "grey", "red4")) +
  theme_bw(base_size = 12) + theme(legend.position = "bottom") +
  xlab("Fold Change") +
  ylab("-log10 adjusted PValue") +
  geom_hline(yintercept = 1.30, size = .25) +
  labs(title = "Volcano plot - Environmental group e Occupational exposure group ")


# heatmap
data.cor <- cor(dat.norm)
image (data.cor, axes=F, main = "Matriz de correlação")
