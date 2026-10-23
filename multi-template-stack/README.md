# **Scalable WordPress Deployment with AWS CloudFormation**

AWS CloudFormationを使用してスケーラブルなWordPress環境をデプロイするためのテンプレートとスクリプトを提供します。以下の手順に従って、必要なリソースを作成し、WordPressをデプロイしてください。

---

## **セットアップ手順**

### **1. パラメータの定義**
まず、`setup-parameters.yml`テンプレートを使用して、データベースユーザー名やパスワードなどの必要なパラメータをAWS Systems Manager Parameter Storeに登録します。

#### **実行手順**
1. `setup-parameters.yml` をCloudFormationにアップロードしてスタックを作成します。
2. スタック作成後、Parameter Storeに以下のキーが登録されます：
   - `WORDPRESS_DB_NAME`: データベース名
   - `WORDPRESS_DB_USER`: データベースユーザー名
   - `WORDPRESS_DB_PASS`: データベースパスワード

#### **CLIコマンド例**
```bash
aws cloudformation deploy \
  --template-file setup-parameters.yml \
  --stack-name setup-parameters-stack \
  --capabilities CAPABILITY_NAMED_IAM
```

---

### **2. テンプレートファイルのS3アップロードとParameter Storeへの登録**
次に、`upload_and_register.sh`スクリプトを使用して、CloudFormationテンプレートファイルを指定したS3バケットにアップロードし、そのURLをParameter Storeに登録します。

#### **事前準備**
- スクリプト内のS3バケット名（例：`cfn-wordpress-multitemplate`）を適切なバケット名に書き換えてください。
- 名前付きプロファイルを使う場合は、実行前に `export AWS_PROFILE=<プロファイル名>` を設定してください（未設定なら既定の資格情報を使います）。

#### **実行手順**
1. `upload_and_register.sh` を実行します。
2. スクリプトは以下の処理を自動で行います：
   - `templates/`ディレクトリ内のテンプレートファイルを指定したS3バケットにアップロード。
   - 各テンプレートのS3 URLをParameter Storeに登録。

#### **CLIコマンド例**
```bash
./upload_and_register.sh
```

#### **出力例**
```
Uploading computing.yml to S3...
Registering computing-url in Parameter Store...
Uploaded and registered: computing.yml -> computing-url

Uploading database.yml to S3...
Registering database-url in Parameter Store...
Uploaded and registered: database.yml -> database-url

All templates have been uploaded and registered in Parameter Store.
```

---

### **3. メインテンプレートの実行**
最後に、`main.yml`テンプレートをCloudFormationにアップロードしてスタックを作成します。このテンプレートは、すべてのリソース（VPC, EC2, RDS, ALBなど）を統合してデプロイします。

#### **実行手順**
1. `main.yml` をCloudFormationにアップロードしてスタックを作成します。
2. スタック作成後、以下のリソースが生成されます：
   - VPC（サブネット、ルートテーブルなど）
   - Auto Scaling Group（EC2インスタンス）
   - RDS（MySQLデータベース）
   - Application Load Balancer（ALB）

#### **CLIコマンド例**
```bash
aws cloudformation deploy \
  --template-file main.yml \
  --stack-name wordpress-main-stack \
  --capabilities CAPABILITY_NAMED_IAM
```

---

## **確認手順**

### **1. ELBのDNS名でアクセス確認**
スタック作成後、AWS Management ConsoleまたはCLIでELB（Application Load Balancer）のDNS名を取得し、ブラウザでアクセスしてください。

#### **CLIコマンド例**
```bash
aws elbv2 describe-load-balancers \
  --names <Your-ALB-Name> \
  --query "LoadBalancers[0].DNSName"
```

期待される結果：
- WordPressのセットアップ画面が表示されます。

---

## **注意事項**

1. **S3バケット名**
   - `upload_and_register.sh`スクリプト内で指定するS3バケット名は事前に作成し、適切な名前に書き換えてください。
   ```bash
   aws s3 mb s3://<your-bucket-name> --region <your-region>
   ```

2. **IAMポリシー**
   - CloudFormationスタックやEC2インスタンスがParameter Storeやその他AWSリソースにアクセスできるよう、適切なIAMポリシーが設定されていることを確認してください。

3. **セキュリティグループ設定**
   - ELBおよびEC2インスタンス間の通信が許可されていること、およびインターネットからELBへのHTTPアクセスが許可されていることを確認してください。

---

## **ディレクトリ構造**

```
.
├── templates/
│   ├── computing.yml
│   ├── database.yml
│   ├── filesystem.yml
│   ├── firewall.yml
│   ├── loadbalancer.yml
│   └── network.yml
├── setup-parameters.yml
├── main.yml
├── upload_and_register.sh
└── README.md
```

---
