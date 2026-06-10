# Creative Studio Frontend

This project was generated with [Angular CLI](https://github.com/angular/angular-cli) version 18.1.2.

## Development server

Run `ng serve` for a dev server. Navigate to `http://localhost:4200/`. The application will automatically reload if you change any of the source files.

## Code scaffolding

Run `ng generate component component-name` to generate a new component. You can also use `ng generate directive|pipe|service|class|guard|interface|enum|module`.

## Build

Run `ng build` to build the project. The build artifacts will be stored in the `dist/` directory.

## Running unit tests

Run `ng test` to execute the unit tests via [Karma](https://karma-runner.github.io).

## Running end-to-end tests

Run `ng e2e` to execute the end-to-end tests via a platform of your choice. To use this command, you need to first add a package that implements end-to-end testing capabilities.

## Further help

To get more help on the Angular CLI use `ng help` or go check out the [Angular CLI Overview and Command Reference](https://angular.dev/tools/cli) page.



## Run local
Copy from environments/environment.ts and create a new file environments/environment.development.ts
The same for Test and Production

```bash
  npm run start
```


## Deploy to Firebase

### Local Deployment
```bash
  npm run build-dev

  firebase logout
  firebase login --reauth
  firebase use --add <your gcp project>
  firebase deploy
```

### Automated Deployment (Cloud Build CI/CD)

This project uses a **two-stage Cloud Build pipeline**:

**Stage 1: `cloudbuild.yaml` (Build Project)**
- Installs dependencies
- Builds the Angular application
- Triggers the deployment to the target project

**Stage 2: `cloudbuild-deploy.yaml` (Target Project)**
- Injects environment variables and secrets from Cloud Build substitutions
- Validates all required configuration is present
- Builds the final production image
- Deploys to Firebase Hosting

#### Why Two Files?
This multi-project pattern allows:
- **Security separation**: Build and deployment can happen in different GCP projects
- **Environment isolation**: Dev, staging, and production can have separate configurations
- **Reduced blast radius**: Credentials only exist where needed

#### Configuration
The deployment pipeline is configured in Terraform:
- File: `infra/modules/services/frontend/main.tf`
- Cloud Build trigger automatically runs on code push
- Environment variables and secrets are injected via build substitutions


