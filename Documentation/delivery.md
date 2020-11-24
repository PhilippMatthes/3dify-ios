# Delivery guide

This project uses [Fastlane](https://fastlane.tools/) to continuously deliver this project to TestFlight. The project is built and published automatically when a new tag is committed with the scheme "v*". For a specific naming scheme see our [contributing guidelines](contributing.md#git-workflow). All of this is facilitated in a GitHub Actions workflow. To see what exactly happens during the workflow, you can take a look at the `.github` folder in this project.

## Configuration

To configure the workflow for the delivery of the App to a new Apple Developer account, please follow the steps in this section.

### Fastlane configuration

First of all, if you want to switch to a new Apple Developer Account, you need to replace the beta configuration in the [Fastfile](/fastlane/Fastfile). It may look something like this:

```ruby
# ...
beta_app_review_info: {
  contact_email: "contact@philippmatth.es",
  contact_first_name: "Philipp",
  contact_last_name: "Matthes",
  contact_phone: "017642090978",
  notes: "Thank you for reviewing the 3Dify App!"
},
localized_app_info: {
  "default": {
    feedback_email: "feedback@philippmatth.es",
    marketing_url: "https://philippmatth.es",
    privacy_policy_url: "https://philippmatth.es",
    description: "This is the TestFlight Beta version for the 3Dify App.",
  }
},
# ...
```

### Project and certificates setup

![signing](images/signing.png)

Under the **Release** section of the project, make sure that "automatically manage signing" is disabled. This is important, because we later want Fastlane to manually sign our application. Create an [App Store identifier](https://developer.apple.com/account/resources/identifiers/list) and a [distribution provisioning profile](https://developer.apple.com/account/resources/profiles/list) for your applicable signing certificate. If you don't know which signing certificate is applicable, look into your keychain:

![signing-cert](images/signing-cert.png)

Download the created profile.

![signing-import](images/signing-import.png)

Import the profile into the project using the "provisioning profile" menu in the **Release** build configuration.

![signing-contents](images/signing-contents.png)

Click the "information" button of the "provisioning profile" section to verify that all certificates are available. If you have a missing certificate, you may have selected the wrong signing certificate. Or you forgot to add your signing certificate to your keychain.

### Create an App Store Connect API key

Open [App Store Connect](https://appstoreconnect.apple.com/) under the section [Users and Access](https://appstoreconnect.apple.com/access/users). Go to the [API key tab](https://appstoreconnect.apple.com/access/api). Create a new API key. Download the API key and note the key's issuer id + the key's id (included in the filename).

Update the following GitHub secrets:
- `APP_STORE_CONNECT_API_KEY_ID`: your key id
- `APP_STORE_CONNECT_API_KEY_ISSUER`: your key issuer

Locate your API key and run `cat path/to/your/api-key.p8 | base64`.

Update the following GitHub secret:
- `APP_STORE_CONNECT_API_KEY`: your base64 encoded api key.

### Export your signing certificate

Create a new random password using `./generate-password.sh`. Copy your password.

Update the following GitHub secret:
- `SIGNING_CERTIFICATE_PASSWORD`: your generated password

To sign your app, you must export your signing certificate. Open your keychain and look up your signing certificate. From the "File" menu, click on "Export Items..." and leave the format set to "Personal Information Exchange (.p12)". **Choose the password that you just created.** Confirm the Keychain export and store your .p12 file safely. Locate your .p12 file. Run `cat path/to/your/signing-cert.p12 | base64` and copy your key data.

Update the following GitHub secret:
- `SIGNING_CERTIFICATE_P12_DATA`: your .p12 key data

### Export your provisioning profile

Locate your provisioning profile. Run `cat path/to/your/profile.mobileprovision | base64` and copy the base64 encoded data.

Update the following GitHub secret:
- `PROVISIONING_PROFILE_DATA`: the copied provisioning profile data

### Create an app

If you haven't already, create an app in App Store Connect under the previously selected App Identifier.

### Test whether everything works

- Make sure that you have installed all project dependencies via `bundle install`.
- Run `bundle exec fastlane gym` and verify that your app actually builds.
- Commit your changes and tag the current version with the recommended [tag scheme](contributing.md#git-workflow).
- Push your changes and monitor the GitHub actions workflow.
