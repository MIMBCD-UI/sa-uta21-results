# Read the dataset
df <- read.csv("data/mimbcdui_uta21_case_data.csv")

# Convert the BI-RADS columns to factors with explicitly defined levels (1 to 5)
# This ensures our matrix will always be 5x5
df$birads_assistant <- factor(df$birads_assistant, levels = 1:5)
df$birads_radiologist <- factor(df$birads_radiologist, levels = 1:5)

# 3. Generate the confusion matrix using the table() function
conf_matrix <- table(Assistant = df$birads_assistant, Radiologist = df$birads_radiologist)

# 4. Print the result
print(conf_matrix)

# Matrix along with detailed statistical metrics

# install.packages("caret")
library(caret)

# Confusion matrix along with detailed statistical metrics
confusionMatrix(df$birads_assistant, df$birads_radiologist)
