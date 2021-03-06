#' Decision tree surrogate model
#' 
#' @description 
#' tree.surrogate() fits a decision tree on the predictions of a machine learning model to make it interpretable.
#' 
#' @details  
#' A conditional inference tree is fitted on the predicted \eqn{\hat{y}} from the machine learning model and the data \eqn{X}.
#' The \code{partykit} package and function are used to fit the tree. 
#' By default a tree of maximum depth of 2 is fitted to improve interpretability.
#' @template arg_sample.size
#' @template args_experiment_wrap
#' @param maxdepth The maximum depth of the tree. Default is 2. 
#' @param tree.args A list with further arguments for \code{ctree}
#' 
#' @return 
#' A TreeSurrogate object (R6). Its methods and variables can be accessed with the \code{$}-operator:
#' \item{tree}{the fitted tree of class \code{party}. See also \link[partykit]{ctree}.}
#' \item{maxdepth}{the maximal tree depth set by the user.}
#' \item{data()}{method to extract the results of the tree. 
#' Returns the sampled feature X together with the leaf node information (columns ..node and ..path) 
#' and the predicted \eqn{\hat{y}} for tree and machine learning model (columns starting with ..y.hat).}
#' \item{plot()}{method to plot the leaf nodes of the surrogate decision tree. See \link{plot.TreeSurrogate}}
#' \item{predict()}{method to predict new data with the tree. See also \link{predict.TreeSurrogate}}
#' @template args_internal_methods
#' 
#' @examples 
#' # Fit a Random Forest on the Boston housing data set
#' library("randomForest")
#' data("Boston", package  = "MASS")
#' mod = randomForest(medv ~ ., data = Boston, ntree = 50)
#' 
#' # Fit a decision tree as a surrogate for the whole random forest
#' dt = tree.surrogate(mod, Boston[-which(names(Boston) == 'medv')], 200)
#' 
#' # Plot the resulting leaf nodes
#' plot(dt) 
#' 
#' # Use the tree to predict new data
#' predict(dt, Boston[1:10,])
#' 
#' # Extract the results
#' dat = dt$data()
#' head(dat)
#' 
#' 
#' # It also works for classification
#' mod = randomForest(Species ~ ., data = iris, ntree = 50)
#' 
#' # Fit a decision tree as a surrogate for the whole random forest
#' X = iris[-which(names(iris) == 'Species')]
#' dt = tree.surrogate(mod, X, 200, predict.args = list(type = 'prob'), maxdepth=2, class=3)
#'
#' # Plot the resulting leaf nodes
#' plot(dt) 
#' 
#' # If you want to visualise the tree directly:
#' plot(dt$tree)
#' 
#' # Use the tree to predict new data
#' set.seed(42)
#' iris.sample = X[sample(1:nrow(X), 10),]
#' predict(dt, iris.sample)
#' predict(dt, iris.sample, type = 'class')
#' 
#' # Extract the dataset
#' dat = dt$data()
#' head(dat)
#' @seealso 
#' \link{predict.TreeSurrogate}
#' \link{plot.TreeSurrogate}
#' 
#' For the tree implementation
#' \link[partykit]{ctree}
#' @export
#' @import partykit
tree.surrogate = function(object, X, sample.size=100, class = NULL, maxdepth = 2, tree.args = NULL, ...){
  samp = DataSampler$new(X)
  pred = prediction.model(object, class = class, ...)
  
  TreeSurrogate$new(predictor = pred, sampler = samp, sample.size = sample.size, maxdepth=maxdepth, tree.args = tree.args)$run()
}

#' Surrogate tree prediction
#' 
#' Predict the response for newdata with the surrogate tree
#' 
#' This function makes the TreeSurrogate object call 
#' its iternal object$predict() method. 
#' For examples see \link{tree.surrogate}
#' @param object The surrogate tree. A TreeSurrogate R6 object
#' @param newdata A data.frame for which to predict
#' @param type Either "prob" or "class". Ignored if the surrogate tree does regression. 
#' @param ... Further argumets for \code{predict_party}
#' @return A data.frame with the predicted outcome. 
#' In case of regression it is the predicted \eqn{\hat{y}}. 
#' In case of classification it is either the class probabilities *(for type "prob") or the class label (type "class")
#' @seealso 
#' \link{tree.surrogate}
#' @importFrom stats predict
#' @export
predict.TreeSurrogate = function(object, newdata, type = "prob", ...){
  object$predict(newdata = newdata, type, ...)
}


#' Surrogate tree visualisation
#' 
#' Predict the response for newdata with the surrogate tree
#' Each plot facet is one leaf node and visualises the distribution of the \eqn{\hat{y}}
#' from the machine learning model. 
#' This makes the TreeSurrogate object call 
#' its iternal object$plot() method. 
#' 
#' For examples see \link{tree.surrogate}
#' @param object The surrogate tree. A TreeSurrogate R6 object
#' @return ggplot2 plot object
#' @seealso 
#' \link{tree.surrogate}
plot.TreeSurrogate = function(object){
  object$plot()
}

## Craven, M. W., & Shavlik, J. W. (1996).
## Extracting tree-structured representations of trained neural networks.
## Advances in Neural Information Processing Systems, 8, 24–30.
## Retrieved from citeseer.ist.psu.edu/craven96extracting.html
TreeSurrogate = R6::R6Class('TreeSurrogate',
  inherit = Experiment,
  public = list(
    # The fitted tree
    tree = NULL,
    # Maximal depth as set by the user
    maxdepth = NULL,
    sample.size = NULL,
    initialize = function(predictor, sampler, sample.size, maxdepth, tree.args){
      super$initialize(predictor, sampler)
      self$sample.size = sample.size
      private$tree.args = tree.args
      self$maxdepth = maxdepth
      private$get.data = function(...) private$sampler$sample(n = self$sample.size, ...)
    }, 
    predict = function(newdata, type = 'prob', ...){
      assert_choice(type, c('prob', 'class'))
      res = data.frame(predict(self$tree, newdata = newdata, type = 'response', ...))
      if(private$multi.class){
        if(type == 'class') {
          res = data.frame(..class = colnames(res)[apply(res, 1, which.max)])
        }
      } else {
        res = data.frame(..y.hat = predict(self$tree, newdata = newdata, ...))
      }
      res
    }
  ), 
  private = list(
    tree.args = NULL,
    # Only relevant in multi.class case
    tree.predict.colnames = NULL,
    # Only relevant in multi.class case
    object.predict.colnames = NULL,

    intervene = function(){private$X.sample},
    aggregate = function(){
      y.hat = private$Q.results
      if(private$multi.class){
        classes = colnames(y.hat)
        form = formula(sprintf("%s ~ .", paste(classes, collapse = "+")))       
      } else {
        y.hat = unlist(y.hat[1])
        form = y.hat ~ .
      }
      dat = cbind(y.hat, private$X.design)
      tree.args = c(list(formula = form, data = dat, maxdepth = self$maxdepth), private$tree.args)
      self$tree = do.call(partykit::ctree, tree.args)
      result = data.frame(..node = predict(self$tree, type = 'node'), 
        ..path = pathpred(self$tree))
      if(private$multi.class){
        outcome = private$Q.results
        colnames(outcome) = paste('..y.hat:', colnames(outcome), sep='')
        private$object.predict.colnames = colnames(outcome)
        
        # result = gather(result, key = "..class", value = "..y.hat", one_of(cnames))
        ..y.hat.tree = self$predict(private$X.design, type = 'prob')
        colnames(..y.hat.tree) = paste('..y.hat.tree:', colnames(..y.hat.tree), sep='')
        private$tree.predict.colnames = colnames(..y.hat.tree)
        
        #..y.hat.tree = gather(..y.hat.tree, '..class.tree', '..y.hat.tree')
        result = cbind(result, outcome, ..y.hat.tree)
      } else {
        result$..y.hat = private$Q.results[[1]]
        result$..y.hat.tree = self$predict(private$X.design)[[1]]
      }
      design = private$X.design
      rownames(design) = NULL
      cbind(design, result)
    }, 
    generate.plot = function(){
      p = ggplot(private$results) + 
        geom_boxplot(aes(y = ..y.hat, x = "")) + 
        scale_x_discrete('') + 
        facet_wrap("..path")
      if(private$multi.class){
        plot.data = private$results
        # max class for model
        plot.data$..class = private$object.predict.colnames[apply(plot.data[private$object.predict.colnames], 1, which.max)]
        plot.data$..class = gsub('..y.hat:', '', plot.data$..class)
        plot.data = plot.data[setdiff(names(plot.data), private$object.predict.colnames)]
        # dataset from wide to long
        #plot.data$..class.tree = private$tree.predict.colnames[apply(plot.data[private$tree.predict.colnames], 1, which.max)]
        #plot.data$..class.tree = gsub('..y.hat.tree:', '', plot.data$..class.tree)
        #plot.data = plot.data[setdiff(names(plot.data), private$tree.predict.colnames)]        
        p = ggplot(plot.data) + 
          geom_bar(aes(x = ..class)) + 
          facet_wrap("..path")
      }
      p
    }
    
  )
)


# Return the paths of a ctree for each training data point
pathpred <- function(object, ...)
{
  ## coerce to "party" object if necessary
  if(!inherits(object, "party")) object = partykit::as.party(object)

  ## get rules for each node
  rls = list.rules.party(object)
  
  ## get predicted node and select corresponding rule
  rules = rls[as.character(predict(object, type = "node", ...))]
  rules = gsub("&", "&\n", rules)
  
  return(rules)
}
