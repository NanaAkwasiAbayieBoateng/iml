% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/feature.imp.R
\name{feature.imp}
\alias{feature.imp}
\title{Feature importance}
\usage{
feature.imp(object, X, y, class = NULL, loss, method = "shuffle", ...)
}
\arguments{
\item{object}{The machine learning model. Different types are allowed. 
Recommended are mlr WrappedModel and caret train objects. The \code{object} can also be 
a function that predicts the outcome given features or anything with an S3 predict function,
like an object from class \code{lm}.}

\item{X}{data.frame with the data for the prediction model}

\item{y}{The vector or data.frame with the actual target values associated with X.}

\item{class}{In case of classification, class specifies the class for which to predict the probability. 
By default the multiclass classification is done.}

\item{loss}{The loss function. A string (e.g. "ce" for classification or "mse") or a function. See Details.}

\item{method}{Either 'shuffle' or 'cartesian'. See Details.}

\item{...}{Further arguments  for the prediction method.}
}
\value{
An Importance object (R6). Its methods and variables can be accessed with the \code{$}-operator:
\item{error.original}{The loss of the model before perturbing features.}
\item{loss}{The loss function. Can also be applied to data: \code{object$loss(actual, predicted)}}
\item{data()}{method to extract the results of the feature importance computation.
Returns a data.frame with importance and permutation error measurements per feature.}
\item{plot()}{method to plot the feature importances. See \link{plot.Importance}}

\item{\code{run()}}{[internal] method to run the interpretability method. Use \code{obj$run(force = TRUE)} to force a rerun.}
General R6 methods
\item{\code{clone()}}{[internal] method to clone the R6 object.}
\item{\code{initialize()}}{[internal] method to initialize the R6 object.}
}
\description{
feature.imp() computes feature importances for machine learning models. 
The importance of a feature is the factor by which the model's prediction error increases when the feature is shuffled.
}
\details{
Read the Interpretable Machine Learning book to learn more about feature importance: 
\url{https://christophm.github.io/interpretable-ml-book/permutation-feature-importance.html}

Two permutation schemes are implemented: 
\itemize{
\item shuffle: A simple shuffling of the feature values, yielding n perturbed instances per feature (faster)
\item cartesian: Matching every instance with the feature value of all other instances, yielding n x (n-1) perturbed instances per feature (slow)
}
The loss function can be either specified via a string, or by handing a function to \code{feature.imp()}.
Using the string is a shortcut to using loss functions from the \code{Metrics} package. 
See \code{library(help = "Metrics")} to get a list of functions. 
Only use functions that return a single performance value, not a vector. 
You can also provide a function directly. It has to take the actual value as its first argument and the prediction as its second.
}
\examples{
# We train a tree on the Boston dataset:
if(require("rpart")){
data("Boston", package  = "MASS")
mod = rpart(medv ~ ., data = Boston)

# Compute the individual conditional expectations for the first feature
X = Boston[-which(names(Boston) == 'medv')]
y = Boston$medv

# Compute feature importances as the performance drop in mean absolute error
imp = feature.imp(mod, X, y, loss = 'mae')

# Plot the results directly
plot(imp)


# Since the result is a ggplot object, you can extend it: 
library("ggplot2")
plot(imp) + theme_bw()

# If you want to do your own thing, just extract the data: 
imp.dat = imp$data()
head(imp.dat)
ggplot(imp.dat, aes(x = ..feature, y = importance)) + geom_point() + 
theme_bw()

# feature.imp() also works with multiclass classification. 
# In this case, the importance measurement regards all classes
mod = rpart(Species ~ ., data= iris)
X = iris[-which(names(iris) == 'Species')]
y = iris$Species
# For some models we have to specify additional arguments for the predict function
imp = feature.imp(mod, X, y, loss = 'ce', predict.args = list(type = 'prob'))
plot(imp)
# Here we encounter the special case that the machine learning model perfectly predicts
# The importance becomes infinite
imp$data()

# For multiclass classification models, you can choose to only compute performance for one class. 
# Make sure to adapt y
imp = feature.imp(mod, X, y == 'virginica', class = 3, loss = 'ce', 
    predict.args = list(type = 'prob'))
plot(imp)
}
}
\references{
Fisher, A., Rudin, C., and Dominici, F. (2018). Model Class Reliance: Variable Importance Measures for any Machine Learning Model Class, from the "Rashomon" Perspective. Retrieved from http://arxiv.org/abs/1801.01489
}
