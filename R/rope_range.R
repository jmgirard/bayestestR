#' @title Find Default Equivalence (ROPE) Region Bounds
#'
#' @description This function attempts at automatically finding suitable "default"
#'   values for the Region Of Practical Equivalence (ROPE).
#'
#' @details \cite{Kruschke (2018)} suggests that the region of practical
#'   equivalence could be set, by default, to a range from \code{-0.1} to
#'   \code{0.1} of a standardized parameter (negligible effect size
#'   according to Cohen, 1988).
#'
#'   \itemize{
#'     \item For \strong{linear models (lm)}, this can be generalised to \ifelse{html}{\out{-0.1 * SD<sub>y</sub>, 0.1 * SD<sub>y</sub>}}{\eqn{[-0.1*SD_{y}, 0.1*SD_{y}]}}.
#'     \item For \strong{logistic models}, the parameters expressed in log odds ratio can be converted to standardized difference through the formula \ifelse{html}{\out{&pi;/&radic;(3)}}{\eqn{\pi/\sqrt{3}}}, resulting in a range of \code{-0.18} to \code{0.18}.
#'     \item For other models with \strong{binary outcome}, it is strongly recommended to manually specify the rope argument. Currently, the same default is applied that for logistic models.
#'     \item For models from \strong{count data}, the residual variance is used. This is a rather experimental threshold and is probably often similar to \code{-0.1, 0.1}, but should be used with care!
#'     \item For \strong{t-tests}, the standard deviation of the response is used, similarly to linear models (see above).
#'     \item For \strong{correlations}, \code{-0.05, 0.05} is used, i.e., half the value of a negligible correlation as suggested by Cohen's (1988) rules of thumb.
#'     \item For all other models, \code{-0.1, 0.1} is used to determine the ROPE limits, but it is strongly advised to specify it manually.
#'   }
#'
#' @param x A \code{stanreg}, \code{brmsfit} or \code{BFBayesFactor} object.
#' @inheritParams rope
#'
#' @examples
#' \dontrun{
#' if (require("rstanarm")) {
#'   model <- stan_glm(
#'     mpg ~ wt + gear,
#'     data = mtcars,
#'     chains = 2,
#'     iter = 200,
#'     refresh = 0
#'   )
#'   rope_range(model)
#'
#'   model <- stan_glm(vs ~ mpg, data = mtcars, family = "binomial", refresh = 0)
#'   rope_range(model)
#' }
#'
#' if (require("brms")) {
#'   model <- brm(mpg ~ wt + cyl, data = mtcars)
#'   rope_range(model)
#' }
#'
#' if (require("BayesFactor")) {
#'   bf <- ttestBF(x = rnorm(100, 1, 1))
#'   rope_range(bf)
#' }
#' }
#' @references Kruschke, J. K. (2018). Rejecting or accepting parameter values in Bayesian estimation. Advances in Methods and Practices in Psychological Science, 1(2), 270-280. \doi{10.1177/2515245918771304}.
#'
#' @importFrom insight get_response model_info is_multivariate
#' @importFrom stats sd
#' @export
rope_range <- function(x, ...) {
  UseMethod("rope_range")
}


#' @export
rope_range.brmsfit <- function(x, ...) {
  response <- insight::get_response(x)
  information <- insight::model_info(x)

  if (insight::is_multivariate(x)) {
    mapply(function(i, j) .rope_range(i, j), x, information, response)
  } else {
    .rope_range(x, information, response)
  }
}


#' @export
rope_range.stanreg <- rope_range.brmsfit

#' @export
#' @importFrom stats sd
rope_range.BFBayesFactor <- function(x, ...) {
  fac <- 1
  if (inherits(x@numerator[[1]], "BFlinearModel")) {
    response <- tryCatch(
      {
        insight::get_response(x)
      },
      error = function(e) {
        NULL
      }
    )

    if (!is.null(response)) {
      fac <- stats::sd(response, na.rm = TRUE)
    }
  }

  fac * c(-0.1, 0.1)
}

#' @export
rope_range.lm <- rope_range.brmsfit

#' @export
rope_range.glm <- rope_range.brmsfit

#' @export
rope_range.merMod <- rope_range.brmsfit

#' @export
rope_range.glmmTMB <- rope_range.brmsfit

#' @export
rope_range.mixed <- rope_range.brmsfit

#' @export
rope_range.MixMod <- rope_range.brmsfit

#' @export
rope_range.wbm <- rope_range.brmsfit

#' @export
rope_range.feis <- rope_range.brmsfit

#' @export
rope_range.gee <- rope_range.brmsfit

#' @export
rope_range.geeglm <- rope_range.brmsfit

#' @export
rope_range.lme <- rope_range.brmsfit

#' @export
rope_range.felm <- rope_range.brmsfit

#' @export
rope_range.fixest <- rope_range.brmsfit

#' @export
rope_range.gls <- rope_range.brmsfit

#' @export
rope_range.hurdle <- rope_range.brmsfit

#' @export
rope_range.zeroinfl <- rope_range.brmsfit

#' @export
rope_range.bayesQR <- rope_range.brmsfit

#' @export
rope_range.default <- function(x, ...) {
  c(-.1, .1)
}

#' @export
rope_range.mlm <- function(x, ...) {
  response <- insight::get_response(x)
  information <- insight::model_info(x)

  lapply(response, function(i) .rope_range(x, information, i))
}




# helper ------------------


#' @importFrom stats sigma sd
#' @importFrom insight n_obs find_parameters
.rope_range <- function(x, information, response) {
  negligible_value <- tryCatch(
    {
      # Linear Models
      if (information$is_linear) {
        0.1 * stats::sd(response, na.rm = TRUE)

        # Logistic Regression Models
      } else if (information$is_binomial) {
        0.1 * pi / sqrt(3)

        # Count Models
      } else if (information$is_count) {
        sig <- stats::sigma(x)
        if (!is.null(sig) && length(sig) > 0 && !is.na(sig)) {
          0.1 * sig
        } else {
          0.1
        }

        # T-tests
      } else if (information$is_ttest) {
        if ("BFBayesFactor" %in% class(x)) {
          0.1 * stats::sd(x@data[, 1])
        } else {
          warning("Could not estimate a good default ROPE range. Using 'c(-0.1, 0.1)'.", call. = FALSE)
          0.1
        }

        # Correlations
      } else if (information$is_correlation) {
        # https://github.com/easystats/bayestestR/issues/121
        0.05

        # Default
      } else {
        0.1
      }
    },
    error = function(e) {
      warning("Could not estimate a good default ROPE range. Using 'c(-0.1, 0.1)'.", call. = FALSE)
      0.1
    }
  )

  c(-1, 1) * negligible_value
}
