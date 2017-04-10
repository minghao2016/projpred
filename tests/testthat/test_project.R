# tests for project

set.seed(1235)
n <- 40
nv <- 5
x <- matrix(rnorm(n*nv, 0, 1), n, nv)
b <- runif(nv)-0.5
dis <- runif(1, 1, 2)
weights <- sample(1:4, n, replace = T)
chains <- 1
cores <- 1
seed <- 1235
iter <- 300
# change this to something else once offsets work
offset <- rep(0, n)

f_gauss <- gaussian()
df_gauss <- data.frame(y = rnorm(n, f_gauss$linkinv(x%*%b), dis), x = x)
f_binom <- binomial()
df_binom <- data.frame(y = rbinom(n, weights, f_binom$linkinv(x%*%b)), x = x)
f_poiss <- poisson()
df_poiss <- data.frame(y = rpois(n, f_poiss$linkinv(x%*%b)), x = x)

fit_gauss <- stan_glm(y ~ x, family = f_gauss, data = df_gauss, QR = T,
                      weights = weights, offset = offset,
                      chains = chains, cores = cores, seed = seed, iter = iter)
fit_binom <- stan_glm(cbind(y, weights-y) ~ x, family = f_binom, QR = T,
                      data = df_binom, weights = weights, offset = offset,
                      chains = chains, cores = cores, seed = seed, iter = iter)
fit_poiss <- stan_glm(y ~ x, family = f_poiss, data = df_poiss, QR = T,
                      weights = weights, offset = offset,
                      chains = chains, cores = cores, seed = seed, iter = iter)

fit_list <- list(fit_gauss, fit_binom, fit_poiss)
vs_list <- lapply(fit_list, varsel, nv_max = nv, verbose = FALSE)


context('project')
test_that("object retruned by project contains the relevant fields", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    p <- project(vs_list[[i]])
    expect_equal(length(p), nv + 1, info = i_inf)

    for(j in 1:length(p)) {
      expect_named(p[[j]], c('kl', 'weights', 'dis', 'alpha', 'beta', 'ind',
                             'intercept', 'ind_names', 'family_kl'),
                   ignore.order = T, info = i_inf)
      # number of draws should equal to the number of draw weights
      ns <- length(p[[j]]$weights)
      expect_equal(length(p[[j]]$alpha), ns, info = i_inf)
      expect_equal(length(p[[j]]$dis), ns, info = i_inf)
      expect_equal(ncol(p[[j]]$beta), ns, info = i_inf)
      # j:th element should have j-1 variables
      expect_equal(nrow(p[[j]]$beta), j - 1, info = i_inf)
      expect_equal(length(p[[j]]$ind), j - 1, info = i_inf)
      expect_equal(length(p[[j]]$ind_names), j - 1, info = i_inf)
      # family kl
      expect_equal(p[[j]]$family_kl, vs_list[[i]]$varsel$family_kl,
                   info = i_inf)
    }
    # kl should be non-increasing on training data
    klseq <- sapply(p, function(x) x$kl)
    expect_equal(klseq, cummin(klseq), info = i_inf)

    # all submodels should use the same clustering
    expect_equal(p[[1]]$weights, p[[nv]]$weights, info = i_inf)
  }
})

test_that("project: error when varsel has not been performed for the object", {
  expect_error(project(1))
  expect_error(project(fit_gauss))
})

test_that("project: setting nv = 3 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    nv <- 0
    p <- project(vs_list[[i]], nv = nv)
    # if only one model size is projected, do not return a list of length one
    expect_true(length(p) >= 1, info = i_inf)
    # beta has the correct number of rows
    expect_equal(nrow(p$beta), nv, info = i_inf)
    expect_equal(length(p$ind), nv, info = i_inf)
    expect_equal(length(p$ind_names), nv, info = i_inf)
  }
})

test_that("project: setting nv = 3 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    nv <- 3
    p <- project(vs_list[[i]], nv = nv)
    # if only one model is projected, do not return a list of length one
    expect_true(length(p) >= 1, info = i_inf)
    # beta has the correct number of rows
    expect_equal(nrow(p$beta), nv, info = i_inf)
    expect_equal(length(p$ind), nv, info = i_inf)
    expect_equal(length(p$ind_names), nv, info = i_inf)
  }
})

test_that("project: setting nv>nv_max returns an error", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    expect_error(project(vs_list[[i]], nv = nv + 1), info = i_inf)
  }
})

test_that("project: setting vind to 4 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    vind <- 4
    p <- project(vs_list[[i]], vind = vind)
    expect_equal(p$ind, vind, info = i_inf)
    expect_equal(nrow(p$beta), 1, info = i_inf)
    exp_ind <- which(vs_list[[i]]$varsel$chosen == vind)
    expect_equal(p$ind_names, vs_list[[i]]$varsel$chosen_names[exp_ind],
                 info = i_inf)
  }
})

test_that("project: setting vind to 1:2 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    vind <- 1:2
    p <- project(vs_list[[i]], vind = vind)
    expect_equal(p$ind, vind, info = i_inf)
    expect_equal(nrow(p$beta), length(vind), info = i_inf)
    exp_ind <- sapply(vind, function(x) which(vs_list[[i]]$varsel$chosen == x))
    expect_equal(p$ind_names, vs_list[[i]]$varsel$chosen_names[exp_ind],
                 info = i_inf)
  }
})

test_that("project: setting vind to something nonsensical returns an error", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    vind <- 1:10
    expect_error(project(vs_list[[i]], vind = vind), info = i_inf)
    vind <- 17
    expect_error(project(vs_list[[i]], vind = vind), info = i_inf)
  }
})

test_that("project: setting ns to 1 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    ns <- 1
    p <- project(vs_list[[i]], ns = ns, nv = nv)
    # expected number of draws
    expect_equal(length(p$weights), ns, info = i_inf)
    expect_equal(length(p$alpha), ns, info = i_inf)
    expect_equal(length(p$dis), ns, info = i_inf)
    expect_equal(ncol(p$beta), ns, info = i_inf)
    expect_equal(p$weights, 1, info = i_inf)
  }
})

test_that("project: setting ns to 40 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    ns <- 40
    p <- project(vs_list[[i]], ns = ns, nv = nv)
    # expected number of draws
    expect_equal(length(p$weights), ns, info = i_inf)
    expect_equal(length(p$alpha), ns, info = i_inf)
    expect_equal(length(p$dis), ns, info = i_inf)
    expect_equal(ncol(p$beta), ns, info = i_inf)

    # no clustering, so draw weights should be identical
    expect_true(do.call(all.equal, as.list(p$weights)), info = i_inf)
  }
})

test_that("project: setting nc to 1 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    nc <- 1
    p <- project(vs_list[[i]], nc = nc, nv = nv)
    # expected number of draws
    expect_equal(length(p$weights), nc, info = i_inf)
    expect_equal(length(p$alpha), nc, info = i_inf)
    expect_equal(length(p$dis), nc, info = i_inf)
    expect_equal(ncol(p$beta), nc, info = i_inf)
  }
})

test_that("project: setting nc to 20 has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    nc <- 20
    p <- project(vs_list[[i]], nc = nc, nv = nv)
    # expected number of draws
    expect_equal(length(p$weights), nc, info = i_inf)
    expect_equal(length(p$alpha), nc, info = i_inf)
    expect_equal(length(p$dis), nc, info = i_inf)
    expect_equal(ncol(p$beta), nc, info = i_inf)
  }
})

test_that("project: setting ns or nc to too big throws an error", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    expect_error(project(vs_list[[i]], ns = 400000, nv = nv), info = i_inf)
    expect_error(project(vs_list[[i]], nc = 400000, nv = nv), info = i_inf)
  }
})

test_that("project: specifying intercept has an expected effect", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    p <- project(vs_list[[i]], nv = nv, intercept = TRUE)
    expect_true(p$intercept, info = i_inf)
    p <- project(vs_list[[i]], nv = nv, intercept = FALSE)
    expect_true(!p$intercept, info = i_inf)
    expect_true(all(p$alpha==0), info = i_inf)
  }
})

test_that("project: specifying the seed does not cause errors", {
  for(i in 1:length(vs_list)) {
    i_inf <- names(vs_list)[i]
    p <- project(vs_list[[i]], nv = nv, seed = seed)
    expect_named(p, c('kl', 'weights', 'dis', 'alpha', 'beta', 'ind',
                      'intercept', 'ind_names', 'family_kl'),
                 ignore.order = T, info = i_inf)
  }
})