# ---------------------------------------------------------- #
# ----------------- Sensitivity analyses ------------------- #
# ---------------------------------------------------------- #

#######################################################################
sink(file="./results/sensitivity_analyses.txt")
#######################################################################

# Packages
require(survival)
require(splines)
require(metafor)
require(dplyr)
require(plotly)
require(reshape2)
require(lme4)
require(mice)
require(RColorBrewer)
require(gmodels)

# some colors
cols1 <- brewer.pal(9,name="BuGn")
cols2 <- brewer.pal(9,name="Oranges")

cat("\n\n--------------------------------------------------------------------\n\n")
cat("\n\n--------------------- Two-stage meta-analysis ----------------------\n\n")
cat("\n\n--------------------------------------------------------------------\n\n")

cat("********** Undjusted model ************\n\n")

outputs_select <- readRDS("./shiny_app/journal_ORs.rds")

# # Check: using the rma function should give the same result as rma.mv above.
# all_2stage <- rma.mv(effect,sd^2,random=~1|journal,data=outputs_select)
# cat("---Summary of random effects meta-analysis for unadjusted model---\n\n")
# summary(all_2stage)
# cat("\n\n---Mean and confidence (ci)/prediction (cr) intervals on odds ratio scale---\n\n")
# predict(all_2stage, transf=exp, digits=2)

cat("--------------------------------------------------\n\n")
cat("--------------------- eTable 7 -------------------\n\n")
cat("--------------------------------------------------\n\n")

# Meta-analysis for unadjusted model
all_2stage <- rma(effect,sd^2,data=outputs_select)
cat("---Summary of random effects meta-analysis for unadjusted model---\n\n")
summary(all_2stage)
cat("\n\n---Mean and confidence (ci)/prediction (cr) intervals on odds ratio scale---\n\n")
predict(all_2stage, transf=exp, digits=2)

cat("\n\n---Meta-regression on journal citescore---\n\n")
# Meta-regression on journal citescore
# exclude one journal with high outlier citescore
outputs_select2 <- subset(outputs_select,citescore<20)
cat("Journal with outlier citescore of",max(outputs_select$citescore),":",
    as.character(outputs_select$sourcetitle[outputs_select$citescore>20]))

# define knots
n_knots <- 3 # number of *internal* knots
citescore_by_pub <- unlist(sapply(1:nrow(outputs_select2),function(idx,n_cases,citescore) rep(citescore[idx],n_cases[idx]),
                                  n_cases=outputs_select2$n_cases,citescore=outputs_select2$citescore))
knot_placement <- quantile(citescore_by_pub,probs = seq(0,1,length.out=n_knots+2)[2:(n_knots+1)])
# run meta-regression
meta_analysis_cs <- rma.mv(effect,sd^2,random=~1|journal,
                           mods= ~ ns(citescore,knots=knot_placement),
                           data=outputs_select2)

cat("\n\n---Meta-regression on citescore, excluding one journal as outlier---\n\n")
summary(meta_analysis_cs)

###### Plot of journal-specific ORs with meta-regression on citescore ######
citescore_newmods <- seq(min(outputs_select2$citescore),max(outputs_select2$citescore),0.1)
citescore_bs <- ns(citescore_newmods,knots=knot_placement)
plot_citescore <- predict(meta_analysis_cs,newmods=citescore_bs[1:nrow(citescore_bs),1:ncol(citescore_bs)],
                          transf=exp)
plot_citescore <- plot_citescore[,c("pred","ci.lb","ci.ub","cr.lb","cr.ub")]
plot_citescore$citescore <- citescore_newmods

# Plot
OR_plot <- plot_ly(subset(outputs_select2,n_cases>50), x = ~citescore, y= ~OR,
                   height=600,width=1000, type="scatter",mode="none",
                   name=" ") %>%
  # add horizontal line for null value
  add_trace(x = c(0,18), y= c(1,1), mode = "lines", color=I("black"),
            showlegend=F) %>%
  # add point for OR of each journal
  add_trace(y=~OR, type='scatter',mode='markers',
            size = ~node_size*2, 
            marker=list(sizeref=0.2),
            hoverinfo='none',
            alpha=0.8,
            color=I(cols1[4]),
            name="Journal-specific OR estimate"
  )  %>%
  # annotations
  add_trace(x = 16, y = 5, mode="text",text="Favors women",
            hoverinfo="none",textfont=list(size=20,color=1),
            showlegend=F) %>%
  add_trace(x = 16, y = 1/5, mode="text",text="Favors men",
            hoverinfo="none",textfont=list(size=20,color=1),
            showlegend=F) %>%
  add_ribbons(x=plot_citescore$citescore,y=plot_citescore$pred,
              ymin=plot_citescore$cr.lb, ymax=plot_citescore$cr.ub,
              hoverinfo="none",
              color=I(cols2[3]),
              name="95% prediction interval") %>%
  add_ribbons(x=plot_citescore$citescore,y=plot_citescore$pred,
              ymin=plot_citescore$ci.lb, ymax=plot_citescore$ci.ub,
              hoverinfo="none",
              color=I(cols2[4]),
              name="95% confidence interval") %>%
  add_lines(y=plot_citescore$pred, x=plot_citescore$citescore,
            hoverinfo="none",
            color=I(cols2[5]),
            # line=list(color=I(cols2[1])),
            name="Estimated OR as function\nof Cite Score") %>%
  # layout
  layout(yaxis = list(title="Odds Ratio (log scale)",range=c(-log(2.2),log(2.2)),type="log",
                      tickvals=c(1/4,1/2,1,2,4),
                      ticktext=c("1/4","1/2",
                                 as.character(c(1,2,4)))),
         xaxis = list(title="Journal Cite Score",range=c(0,18),tickmode="array"),
         showlegend=T,
         font=list(size=16)
  )

# Save as pdf
export(OR_plot, "./results/eFigure_9a.pdf")

cat("\n\n********** Adjusted model ************\n\n")

# # Meta-analysis for adjusted model
# all_2stage_adj <- rma.mv(effect_adj,sd_adj^2,random=~1|journal,data=outputs_select)
# cat("\n\n---Summary of random effects meta-analysis for adjusted model---\n\n")
# summary(all_2stage_adj)
# cat("\n\n---Mean and confidence (ci)/prediction (cr) intervals on odds ratio scale---\n\n")
# predict(all_2stage_adj, transf=exp, digits=2)

# Meta-analysis for adjusted model
outputs_select <- readRDS("./shiny_app/journal_ORs.rds")
# Some journals are omitted due to large standard errors
outputs_select$OR_adj[outputs_select$sd_adj>2500] <- NA
outputs_select$sd_adj[outputs_select$sd_adj>2500] <- NA
all_2stage_adj <- rma(effect_adj,sd_adj^2,data=outputs_select)
cat("---Summary of random effects meta-analysis for unadjusted model---\n\n")
summary(all_2stage_adj)
cat("\n\n---Mean and confidence (ci)/prediction (cr) intervals on odds ratio scale---\n\n")
predict(all_2stage_adj, transf=exp, digits=2)

## Save key results for use in plotting ##
save(all_2stage,all_2stage_adj,file="./results/two_stage_analyses.Rdata")

# Meta-regression by citescore
cat("\n\n---Meta-regression on journal citescore---\n\n")
outputs_select2$OR_adj[outputs_select2$sd_adj>2500] <- NA
outputs_select2$sd_adj[outputs_select2$sd_adj>2500] <- NA
meta_analysis_cs_adj <- rma.mv(effect_adj,sd_adj^2,random=~1|journal,
                           mods= ~ ns(citescore,knots=knot_placement),
                           data=subset(outputs_select2,!is.na(outputs_select2$effect_adj)))
cat("\n\nMeta-regression on citescore\n\n")
summary(meta_analysis_cs_adj)

###### Plot of journal-specific ORs with meta-regression on citescore ######
plot_citescore_adj <- predict(meta_analysis_cs_adj,newmods=citescore_bs[1:nrow(citescore_bs),1:ncol(citescore_bs)],
                          transf=exp)
plot_citescore_adj <- plot_citescore_adj[,c("pred","ci.lb","ci.ub","cr.lb","cr.ub")]
plot_citescore_adj$citescore <- citescore_newmods

OR_adj_plot <- plot_ly(subset(outputs_select2,n_cases>50), x = ~citescore, y= ~OR_adj,
                       height=600,width=1000, type="scatter", mode="none",
                       name=" ") %>%
  # add horizontal line for null value
  add_trace(x = c(0,18), y= c(1,1), mode = "lines", color=I("black"),
            showlegend=F) %>%
  # add point for OR of each journal
  add_trace(y=~OR_adj, type='scatter',mode='markers',
            size = ~node_size*2, 
            marker=list(sizeref=0.2),
            hoverinfo='none',
            color=I(cols1[4]),
            alpha=0.8,
            name="Journal-specific OR estimate"
  )  %>%
  # annotations
  add_trace(x = 16, y = 5, mode="text",text="Favors women",
            hoverinfo="none",textfont=list(size=20,color=1),
            showlegend=F) %>%
  add_trace(x = 16, y = 1/5, mode="text",text="Favors men",
            hoverinfo="none",textfont=list(size=20,color=1),
            showlegend=F) %>%
  add_ribbons(x=plot_citescore_adj$citescore,y=plot_citescore_adj$pred,
              ymin=plot_citescore_adj$cr.lb, ymax=plot_citescore_adj$cr.ub,
              hoverinfo="none",
              color=I(cols2[3]),
              name="95% prediction interval")%>%
  add_ribbons(x=plot_citescore_adj$citescore,y=plot_citescore_adj$pred,
              ymin=plot_citescore_adj$ci.lb, ymax=plot_citescore_adj$ci.ub, 
              hoverinfo="none",
              color=I(cols2[4]),
              name="95% confidence interval") %>%
  add_lines(y=plot_citescore_adj$pred, x=plot_citescore_adj$citescore,
            hoverinfo="none",
            color=I(cols2[5]),
            name="Estimated OR as function\nof Cite Score")%>%
  # layout
  layout(yaxis = list(title="Odds Ratio (log scale)",range=c(-log(2.2),log(2.2)),type="log",
                      tickvals=c(1/4,1/2,1,2,4),
                      ticktext=c("1/4","1/2",
                                 as.character(c(1,2,4)))),
         xaxis = list(title="Journal Cite Score",range=c(0,18),tickmode="array"),
         showlegend=T,
         font=list(size=16)
  )

# Save as pdf
export(OR_adj_plot, "./results/eFigure_10b.pdf")

cat("\n\n********** Model with interaction ************\n\n")

# Main effect
outputs_select <- readRDS("./shiny_app/journal_ORs.rds")
# Some estiamtes must be excluded due to large standard errors
# and for consistency with the interaction term below
outputs_select$OR_main[outputs_select$sd_int>290] <- NA
outputs_select$sd_main[outputs_select$sd_int>290] <- NA
all_2stage_main <- rma(effect_main,sd_main^2,data=outputs_select)
cat("---Summary of random effects meta-analysis for unadjusted model---\n\n")
summary(all_2stage_main)
cat("\n\n---Mean and confidence (ci)/prediction (cr) intervals on odds ratio scale---\n\n")
predict(all_2stage_main, transf=exp, digits=2)

# Interaction term
outputs_select <- readRDS("./shiny_app/journal_ORs.rds")
# Some estiamtes must be excluded due to large standard errors
outputs_select$OR_int[outputs_select$sd_int>290] <- NA
outputs_select$sd_int[outputs_select$sd_int>290] <- NA
all_2stage_int <- rma(effect_int,sd_int^2,data=outputs_select)
cat("---Summary of random effects meta-analysis for unadjusted model---\n\n")
summary(all_2stage_int)
cat("\n\n---Mean and confidence (ci)/prediction (cr) intervals on odds ratio scale---\n\n")
predict(all_2stage_int, transf=exp, digits=2)

cat("\n\n---------------------------------------------------------\n\n")
cat("\n\n--------- Multiple imputation for missing data-----------\n\n")
cat("\n\n---------------------------------------------------------\n\n")

icc_df_all <- readRDS(file="./data/processed_data_all.rds")

cat("-----------------Multiple imputation analysis----------------\n\n")

# How many imputed datasets?
n.impute <- 10

# Creata dataframe for running imputation model
icc_df_to_impute <- icc_df_all
icc_df_to_impute$gender <- 0
icc_df_to_impute$gender[icc_df_all$Gender=="female"] <- 1
icc_df_to_impute$gender[icc_df_to_impute$Gender=="unknown"] <- NA
icc_df_to_impute <- icc_df_to_impute[!(is.na(icc_df_to_impute$H_Index) |
                                         is.na(icc_df_to_impute$Total_Publications_In_Scopus) |
                                         is.na(icc_df_to_impute$years_in_scopus_ptile) |
                                         is.na(icc_df_to_impute$asia)),]
icc_df_to_impute <- icc_df_to_impute[,c("pub_sourceid","pub_id","case","gender","asia",
                                        "years_in_scopus_ptile","h_index_ptile","n_pubs_ptile")]
icc_df_to_impute$case_years_in_scopus <- icc_df_to_impute$case*icc_df_to_impute$years_in_scopus_ptile
icc_df_to_impute$case_h_index <- icc_df_to_impute$case*icc_df_to_impute$h_index_ptile
icc_df_to_impute$case_n_pubs <- icc_df_to_impute$case*icc_df_to_impute$n_pubs_ptile

# run imputation model
knots <- c(2.5,5,7.5)
mod_impute <- glmer(gender ~ case + 
               case_years_in_scopus +
               case_h_index +
               case_n_pubs +
               asia +
               ns(years_in_scopus_ptile,knots=knots) + 
               ns(h_index_ptile,knots=knots) + 
               ns(n_pubs_ptile,knots=knots) +
               (1 | pub_id), 
               data = icc_df_to_impute, family = binomial,
               verbose = 2, nAGQ=0)
summary(mod_impute)

# Get predicted probabilities of being female for those with missing gender
p_female <- predict(mod_impute,icc_df_to_impute,
                    type="response",
                    allow.new.levels=TRUE)

# generate imputed datasets
imputed_dfs <- list()
set.seed(3298639)
missing_gender <- is.na(icc_df_to_impute$gender)
for(i in 1:n.impute){
  imputed_df <- icc_df_to_impute
  imputed_df$gender[missing_gender] <- sapply(p_female[missing_gender],rbinom,n=1,size=2)
  imputed_dfs[[i]] <- imputed_df
}
saveRDS(imputed_dfs,file="./data/imputed_data.RDS")

cat("--------------------------------------------------\n\n")
cat("--------------------- eTable 8 -------------------\n\n")
cat("--------------------------------------------------\n\n")

# run unadjusted model on each dataset
imputed_mods <- lapply(imputed_dfs,
                       FUN=clogit,
                       formula=case ~ gender + 
                       strata(pub_id)
                      ) %>% as.mira

cat("\n\n-- Unadjusted results after multiple imputation --\n\n")
res_imp <- summary(pool(imputed_mods))
c(OR=exp(res_imp$estimate),
      ci.lb=exp(res_imp$estimate - 1.96*res_imp$std.error),
      ci.ub=exp(res_imp$estimate + 1.96*res_imp$std.error),
  p.value=res_imp$p.value)

imputed_mods_adj <- lapply(imputed_dfs,
            FUN=clogit,
            formula=case ~ gender +
                     ns(years_in_scopus_ptile,knots=knots) + 
                     ns(h_index_ptile,knots=knots) + ns(n_pubs_ptile,knots=knots) + 
                     strata(pub_id)
              ) %>% as.mira

cat("\n\n-- Adjusted results after multiple imputation --\n\n")
res_imp_adj <- summary(pool(imputed_mods_adj))
res_imp_adj_df <- data.frame(
  OR=exp(res_imp_adj$estimate),
  ci.lb=exp(res_imp_adj$estimate - 1.96*res_imp_adj$std.error),
  ci.ub=exp(res_imp_adj$estimate + 1.96*res_imp_adj$std.error),
  p.value=res_imp_adj$p.value)
row.names(res_imp_adj_df) <- row.names(res_imp_adj)
res_imp_adj_df

imputed_mods_int <- lapply(imputed_dfs,
                           FUN=clogit,
                           formula=case ~ gender + years_in_scopus_ptile:gender + 
                             ns(years_in_scopus_ptile,knots=knots) + 
                             ns(h_index_ptile,knots=knots) + 
                             ns(n_pubs_ptile,knots=knots) + 
                             strata(pub_id)
                    ) %>% as.mira

cat("\n\n-- Adjusted results with interaction after multiple imputation --\n\n")
res_imp_int <- summary(pool(imputed_mods_int))
res_imp_int_df <- data.frame(
  OR=exp(res_imp_int$estimate),
  ci.lb=exp(res_imp_int$estimate - 1.96*res_imp_int$std.error),
  ci.ub=exp(res_imp_int$estimate + 1.96*res_imp_int$std.error),
  p.value=res_imp_int$p.value)
row.names(res_imp_int_df) <- row.names(res_imp_int)
res_imp_int_df

cat("\n\n--------------------------------------------------------------------------------------\n\n")
cat("\n\n------------- De-duplicating case authors present in multiple journals ---------------\n\n")
cat("\n\n-------------------- and stricter match criteria for controls ------------------------\n\n")
cat("\n\n------------ and removing cases that may be replies to other authors -----------------\n\n")
cat("\n\n--------------------------------------------------------------------------------------\n\n")

icc_df <- readRDS(file="./data/processed_data_no_missing.rds")

### Exclude publications that had one of the following words in the title: reply, replies, repsonse, responses, respond, responds 
icc_df <- icc_df[icc_df$only_replies == F | is.na(icc_df$only_replies),]

# de-duplicate case authors
icc_df_case <- icc_df[icc_df$case==1,]
pubs.incl <- unique(icc_df_case$pub_id[!duplicated(icc_df_case$auth_id)])
icc_df_dedup <- icc_df[icc_df$pub_id %in% pubs.incl,]
icc_df_dedup$pub_id <- factor(icc_df_dedup$pub_id,levels=unique(icc_df_dedup$pub_id))

# keep only top two controls
icc_df_dedup <- icc_df_dedup[icc_df_dedup$match_score_rank <= 3,]

cat("--------------------------------------------------\n\n")
cat("--------------------- eTable 9 -------------------\n\n")
cat("--------------------------------------------------\n\n")

cat("\n\n---Unadjusted analysis---\n")
all_1stage_dedup <- clogit(case ~ Gender + strata(pub_id), data = icc_df_dedup)
summary(all_1stage_dedup)

cat("\n\n---Adjusted for measures of seniority using natural cubic splines---\n")
knots <- c(2.5,5,7.5)
all_1stage_dedup_adj <- clogit(case ~ Gender + 
                           ns(years_in_scopus_ptile,knots=knots) + 
                           ns(h_index_ptile,knots=knots) + 
                           ns(n_pubs_ptile,knots=knots) + 
                           strata(pub_id), data = icc_df_dedup)
summary(all_1stage_dedup_adj)

cat("\n\n---Including interaction term between gender and years active---\n")
all_1stage_dedup_int <- clogit(case ~ Gender + 
                                 years_in_scopus_ptile:factor(Gender,levels=c("female","male")) +
                                 ns(years_in_scopus_ptile,knots=knots) + 
                                 ns(h_index_ptile,knots=knots) + 
                                 ns(n_pubs_ptile,knots=knots) + 
                                 strata(pub_id), data = icc_df_dedup)
summary(all_1stage_dedup_int)

#######################################################################
sink()
#######################################################################
