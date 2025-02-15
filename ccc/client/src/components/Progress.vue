<template>
  <v-card>
    <v-card-title>
      ☁️ 🧰 Starting CloudControl
      <v-spacer/>
      <v-progress-circular indeterminate/>
    </v-card-title>
    <v-card-text>
      <p>CloudControl is starting up. Please wait.</p>
      <v-alert :hidden="oAuthCode === '' && oAuthUrl === ''" type="info">
        CloudControlCenter has detected an authentication request. Click here to copy the authentication code
        into the clipboard and open the authentication URL:
        <v-btn v-on:click=doOAuth>
          Open Authentication
        </v-btn>
      </v-alert>
      <v-alert :hidden="!requiresMFA" type="info">
        CloudControlCenter has detected an MFA code request. Enter the current code of your authenticator:
        <v-form v-on:submit=sendMfa>
          <v-text-field autofocus v-model="mfaCode"></v-text-field>
          <v-btn type="submit">Send code</v-btn>
        </v-form>
      </v-alert>
      <v-alert :hidden="currentError === ''" type="error">
        {{ currentError }}
      </v-alert>
      <v-card>
        <v-card-title>Installing {{ stepTitle }}</v-card-title>
        <v-card-text>
          <vue-markdown :source="stepDescription"></vue-markdown>
        </v-card-text>
      </v-card>
      <v-card id="console" dark outlined rounded="0" height="30em" max-height="30em"
              style="font-family: monospace; overflow-y: scroll">
        <v-card-text v-html="consoleOutput"></v-card-text>
      </v-card>
      <v-stepper>
        <v-stepper-header>
          <template v-for="(stepName, step) in steps">
            <v-stepper-step :ref="`${step + 1}-step`" :complete="currentStep - 1 > step" :step="step + 1">{{ stepName }}
            </v-stepper-step>
            <v-divider
                v-if="step !== steps.length"
                :key="step"
            ></v-divider>
          </template>
        </v-stepper-header>
      </v-stepper>
    </v-card-text>
    <v-card-actions>
      <v-progress-linear :value="(currentStep - 1) / steps.length * 100"/>
    </v-card-actions>
  </v-card>
</template>

<script lang=ts>
import Vue from 'vue';
import * as axios from 'axios';
import { Component, Prop } from 'vue-property-decorator';
import VueMarkdown from 'vue-markdown-render';

@Component({
  components: {
    VueMarkdown,
  },
})
export default class Progress extends Vue {
  public steps: string[] = [];
  public currentStep: number = 1;
  public consoleOutput: string = '';

  public getStepInterval: number = -1;

  public oAuthCode: string = '';
  public oAuthUrl: string = '';

  public stepTitle: string = 'Flavour';
  public stepDescription: string = 'Installing and configuring flavour';

  public currentError: string = '';

  public requiresMFA: boolean = false;
  public mfaCode: string = '';

  public mounted() {
    axios.default.get('/api/steps')
        .then(
            (backendSteps) => {
              this.steps = backendSteps.data.steps;
            },
        );
    this.getStepInterval = setInterval(this.getCurrentStep.bind(this), 3000);
  }

  public async doOAuth() {
    await navigator.clipboard.writeText(this.oAuthCode);
    window.open(this.oAuthUrl);
  }

  public getCurrentStep() {
    axios.default.get('/api/steps/current')
        .then(
            (backendStep) => {
              this.stepTitle = backendStep.data.title;
              this.stepDescription = backendStep.data.description;
              this.currentStep = backendStep.data.currentStep;
              const stepRef = (
                  this.$refs[ `${this.currentStep}-step` ] as Vue[]
              )[ 0 ].$el.scrollIntoView();
              this.consoleOutput = this.reformatOutput(backendStep.data.output);
              const consoleCard = document.getElementById('console');
              if (consoleCard) {
                consoleCard.scrollTop = consoleCard.scrollHeight;
              }
            },
        )
        .catch((error) => {
          this.currentError = `Could not reach the ccc backend or the backend has reached an error state. Please
        use docker logs to show the log messages from the CloudControl container for details. The container might
        already been stopped, so you should use docker ps -a to look for it. `;
          if (error.response) {
            this.currentError = this.currentError + `([${error.response.status}] ${error.response.data})`;
          } else if (error.message) {
            this.currentError = this.currentError + `(${error.message})`;
          }
        });
  }

  public reformatOutput(output: string) {
    // Replace newlines with br
    output = output.replaceAll('\n', '<br/>');

    this.oAuthCode = '';
    this.oAuthUrl = '';

    // Oauth feature
    const azureOauthRegexp = new RegExp(
        'https://microsoft.com/devicelogin and enter the code ([^ ]+) to authenticate.',
    );
    if (azureOauthRegexp.test(output)) {
      const matches = azureOauthRegexp.exec(output);
      if (matches) {
        this.oAuthUrl = 'https://microsoft.com/devicelogin';
        this.oAuthCode = matches[ 1 ];
      }
    }

    // MFA feature. Check for a regexp request, but also check if the MFA was already entered.
    const mfaRegexp = new RegExp(
        '/tmp/mfa',
    );
    const mfaDoneRegExp = new RegExp(
        '\[VALID_CODE\]'
    )
    if (mfaRegexp.test(output) && !mfaDoneRegExp.test(output)) {
      this.requiresMFA = true;
    } else {
      this.requiresMFA = false;
    }

    return output;
  }

  public beforeDestroy() {
    clearInterval(this.getStepInterval);
    this.getStepInterval = -1;
  }

  public sendMfa(event: Event) {
    event.preventDefault();
    axios.default.post('/api/mfa', {
      code: this.mfaCode,
    })
        .then(() => {
          this.requiresMFA = false;
          this.currentError = '';
        })
        .catch((error) => {
          this.currentError = 'Can not set MFA code:';
          if (error.response) {
            this.currentError = `${this.currentError} ([${error.response.status}] ${error.response.data})`;
          } else if (error.message) {
            this.currentError = `${this.currentError} (${error.message})`;
          }
        });

  }
}
</script>

<style scoped>
.v-stepper_header {
  overflow: auto;
  display: flex;
  flex-wrap: nowrap;
  justify-content: left;
}
</style>
