FXN_NAME?=crawl-driver
S3_BUCKET?=candid-serverlessrepo
OUTPUT_CF=serverless.yaml
REGION?=us-east-1
APPLICATION_NAME=Crawler
APPLICATION_ID=arn:aws:serverlessrepo:$(REGION):$(AWS_ACN):applications/$(APPLICATION_NAME)
VERSION?=1.0.0

OUT=out
STAMP_SETUP = $(OUT)/stamp-setup

AWS=aws --profile $(AWS_PROFILE)

.DEFAULT_GOAL := $(OUTPUT_CF)

$(STAMP_SETUP):
	mkdir -p $(@D)
	npm i aws-sdk
	touch $@

index.zip: index.js
	zip $@ $<

upgrade: index.zip | $(STAMP_SETUP)
	$(AWS) lambda update-function-code \
		--zip-file fileb://$< \
		--function-name $(FXN_NAME)

clean:
	rm -rf node_modules index.zip $(OUTPUT_CF) $(OUT)

realclean:
	git clean -xdf .

$(OUTPUT_CF): crawl.yaml index.js Makefile | $(STAMP_SETUP)
	sam package \
		--template-file $< \
		--output-template-file $(OUTPUT_CF) \
		--s3-bucket $(S3_BUCKET)

package: $(OUTPUT_CF)

deploy: CONF_YAML=$(APPLICATION_NAME)-$(VERSION).yaml
deploy: $(OUTPUT_CF)
	$(AWS) s3 cp $< s3://$(S3_BUCKET)/$(CONF_YAML)
	$(AWS) serverlessrepo create-application-version \
		--application-id $(APPLICATION_ID) \
		--semantic-version $(VERSION) \
		--source-code-url https://github.com/candidpartners/lambda-at-scale \
		--template-url s3://$(S3_BUCKET)/$(CONF_YAML)
	$(AWS) s3 rm s3://$(S3_BUCKET)/$(CONF_YAML)

destroy:
	$(AWS) cloudformation delete-stack --stack-name $(FXN_NAME)

.PHONY: setup push clean package deploy