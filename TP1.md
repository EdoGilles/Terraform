# TP1 PRISE EN MAIN - Premier déploiement avec Terraform

> **Objectifs du TP**

> * Créer sa première infrastructure Terraform sur AWS
> * Déployer plusieurs types de ressources
> * Comprendre et utiliser le HCL et les commandes Terraform
> * **Savoir utiliser la documentation [Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)**

> **L'ensemble du TP se base sur l'image suivante:**

[architecture.png](archi_tp1.png)

Pensez à lire l'intégralité du sujet avant de vous lancer dans le TP.

## Initialisation du projet Terraform

En premier lieu, n'oubliez pas de créer un fichier .tf dans votre répertoire de travail. Ce fichier .tf contiendra tous les détails de votre infrastructure.
Avant de déployer une quelconque infrastructure, il faut indiquer à Terraform quelques informations relatives au provider, AWS en l'occurence.
Pour ce TP, nous utiliserons une version ~> 5.0 de "hashicorp/aws" et nous nous baserons, de préférence, dans la région eu-west-3.

Une fois ces informations données à AWS, testez la commande **terraform init**.

Vous devriez avoir un résultat similaire:

```console
PS C:\...\workdir\TP1> terraform init

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.16.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

## Création d'un VPC

Une fois que vous avez renseigné les informations relatives au provider, vous pouvez créer un VPC et les subnets qui y sont associés.

### Création du VPC

```aws_vpc```

Créez une ressource de type VPC avec un cidr block de 172.16.0.0/16, en activant le suport du dns, la translation de nom de domaines et en ajoutant un tag "Name".

### Création d'un subnet public

```aws_subnet```

Le premier subnet à créer est un subnet public. Pensez à lui renseigner l'id du VPC, un cidr block (par exemple 172.16.10.0/24) et l'AZ dans laquelle vous souhaitez le déployer.

Petit indice nécessaire pour faire un subnet public, pensez à map une ip publique au démarrage (un tout petit indice qui peut être utile).

Accessoirement, attachez-y un tag Name pour mieux retrouver cette ressource.

### Création d'un subnet privé

```aws_subnet```

Créez à présent un subnet identique mais sans mapper d'adresse ip publique et en mettant un cidr_block différent que le subnet public.

Ce subnet contiendra l'instance 2

## Mapping Réseau

Dans cette partie, votre rôle est de définir les interreactions pouvant avoir lieu entre les différents éléments de votre architecture.

On y retrouvera une internet gateway, une nat gateway, une elastic ip ainsi que plusieurs tables de routages (très simples) et des security group définissant les matrices de flux.

### elastic ip

```aws_eip```

Cette ressource est... simple. Il suffit de lui indiquer qu'elle est dans le domain de type vpc.

### internet gateway

```aws_internet_gateway```

Le premier élément que nous allons créer dans cette partie est une internet gateway. Les seules demandes associées à cette étapes sont le fait de l'associer au vpc via l'id de ce dernier et de lui assigner un nom via un tag.

### nat gateway

```aws_nat_gateway```

Il faudra très peu de choses pour cette ressources. Lui allouer l'ip de l'elastic_ip précédemment créée et lui indiquer dans quel subnet elle se trouve grâce à l'id de ce dernier.

Il est évidemment préférabe d'aussi lui indiquer son nom.

En cas de problème au déploiement, il est possible qu'il faille lui indiquer le code "```depends_on = [aws_internet_gateway.my_igw]```" (où my_igw est le nom de votre internet gateway) pour s'assurer que Terraform ne s'emmele pas les piceaux.

### route tables

```aws_route_table```

#### public route table

La première table de routage devra:

* être associée au vpc via l'id de ce dernier;
* définir un cidr_block cible (tout internet)
* être lié à l'internet_gateway via l'id de cette dernière
* être nommée via un tag Name

#### private route table

Cettte seconde gateway aura exactement les même besoin mais, au lieu de l'internet gateway, elle devra-t-être liée à la Nat gateway.

### tables d'association de routes

```aws_route_table_association```

#### association publique

Cette ressource devra uniquement contenir les id du subnet et de la route table publics.

### association privée

Idem que pour l'association publique mais avec le subnet et la route table privés.

### Security groupes

```aws_security_group```

Cette ressource est un peu plus compliquée. Pour les 2 security groups que nous allons créer, il faudra:

* les associer à un vpc via son id
* indiquer des règles de flux sortants (egress)
* indiquer des règles de flux entrants (ingress)
* leur donner un tag

Les règles de flux sortant seront toujours les suivantes:

```json
from_port   = 0
to_port     = 0
protocol    = -1
cidr_blocks = ["0.0.0.0/0"]
```

Pour les flux entrants, les règles seront de la forme suivante:

```json
from_port   = X
to_port     = X
protocol    = -1
cidr_blocks = ["0.0.0.0/0"]
```

où les X doivent être changés par le port approprié.

#### http-allowed

Ce security group a pour but de permettre l'accès aux flux http vers la machine cible. Le port associé est le **8080**.

#### ssh-allowed

Ce security groupe permet l'accès via ssh à la machine cible. le port associé est le port **22**.

## clé publique

```aws_key_pair```

Ce bloc sert à importer une clef ssh présente sur votre PC dans AWS via Terraform.
Les seuls arguments à y passer sont le nom à doner à la clef et le chemin d'accès sur le PC.

## Instances

```aws_instance```

Enfin, vous allez pouvoir déployer des instances, au nombre de 2. Une première accessible depuis internet et une autre isolée derrière la première.

Les deux instances auront en communt les paramètres suivants:

* image de type ubuntu 22.04 lts fournie par aws
* instancde de type t2.micro
* possèder le bloc suivant:

```json
user_data         = <<-EOF
                    #!/bin/bash
                    echo "Hello, World foo" > index.html
                    python3 -m http.server 8080 &
                    EOF
```

### instance publique

Cette instance aura en plus une clef ssh publique récupérée depuis votre PC et transmise via terraform précédemment.

Elle sera associée avec le nom donné précédemment à la clef.

Cette instance sera placée dans le subnet public et comportera les security groups http-allowed et ssh-allowed.

### instance privée

Cette instance reprend la même base à la différence qu'elle ne comportera pas de clef ssh importée et qu'elle sera associée au subnet privé.

Afin de plus facilement les différencier, il est possible de modifier "*foo*" par "*bar*" dans le Echo qui lui est transmis.

## Vérification

Une fois que vous pensez avoir terminé le TP, connectez vous via ssh à l'instance publique et effectuez une commande curl vers le port 8080 de l'instance privée depuis la publique.

## **Bonus**

Une fois cette architecture réalisée, reproduisez la sur un autre provider (Azure ou GCP par exemple).

Toute initiative pertiente (versionning du code, ajout de tests,... ) sera prise en compte lors de votre présentation.