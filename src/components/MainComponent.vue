<template>
  <v-card>
    <v-toolbar color="indigo" elevation="4">
    <v-btn icon>
      <v-icon>mdi-chart-line</v-icon>
    </v-btn>
      <v-toolbar-title class="toolbar-title">Copilot Metrics Viewer | {{ capitalizedItemName }} : {{ displayedViewName }} 
        <label for="team-select" class="customLabel">Select a team:</label>
        <select id="team-select" ref="teamSelect" v-model="selectedTeam" @change="updateTeam" class="customSelect">
          <option v-for="team in teams" :key="team" :value="team">{{ team }}</option>
        </select>
         
      </v-toolbar-title>
      <h2 class="error-message"> {{ mockedDataMessage }} </h2>
      <v-spacer></v-spacer>

      <template v-slot:extension>

        <v-tabs v-model="tab" align-tabs="title">
          <v-tab v-for="item in tabItems" :key="item" :value="item">
            {{ item }}
          </v-tab>
        </v-tabs>

      </template>

    </v-toolbar>

    <!-- API Error Message -->
    <div v-if="apiError" class="error-message" v-html="apiError"></div>
    <div v-if="!apiError">
      <div v-if="itemName === 'invalid'" class="error-message">Invalid Scope in .env file. Please check the value of VUE_APP_SCOPE.</div>
      <div v-else>
        <v-progress-linear v-if="!metricsReady || !seatsReady" indeterminate color="indigo"></v-progress-linear>
        <v-window v-if="metricsReady" v-model="tab">
          <v-window-item v-for="item in tabItems" :key="item" :value="item">
            <v-card flat>
            <div :key="componentsKey">
              <MetricsViewer v-if="item === itemName" :metrics="metrics" />
              <BreakdownComponent v-if="item === 'languages'" :metrics="metrics" :breakdownKey="'language'"/>
              <BreakdownComponent v-if="item === 'editors'" :metrics="metrics" :breakdownKey="'editor'"/>
              <CopilotChatViewer v-if="item === 'copilot chat'" :metrics="metrics" />
              <SeatsAnalysisViewer v-if="item === 'seat analysis'" :seats="seats" />
              <ApiResponse v-if="item === 'api response'" :metrics="metrics" :seats="seats" />
              <div v-if="item === 'more stats'">
                  <iframe v-if="item === 'more stats'" width="80%" height="800px" src="https://lookerstudio.google.com/embed/reporting/20c86047-544f-4ddf-9fae-d1d76dcfabfe/page/p_mz8bokduld" frameborder="0" style="border:0" allowfullscreen sandbox="allow-storage-access-by-user-activation allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox"></iframe>
              </div>
              </div>
            </v-card>
          </v-window-item>
        </v-window>
      </div>
    </div>

  </v-card>
</template>

<script lang='ts'>
import { defineComponent, ref, onMounted, watch } from 'vue'
import { getMetricsApi } from '../api/GitHubApi';
import { getTeamMetricsApi } from '../api/GitHubApi';
import { getSeatsApi } from '../api/ExtractSeats';
import { Metrics } from '../model/Metrics';
import { Seat } from "../model/Seat";

//Components
import MetricsViewer from './MetricsViewer.vue'
import BreakdownComponent from './BreakdownComponent.vue' 
import CopilotChatViewer from './CopilotChatViewer.vue' 
import SeatsAnalysisViewer from './SeatsAnalysisViewer.vue'
import ApiResponse from './ApiResponse.vue'
import config from '../config';

import { useRoute } from 'vue-router';

export default defineComponent({
  name: 'MainComponent',
  components: {
    MetricsViewer,
    BreakdownComponent,
    CopilotChatViewer,
    SeatsAnalysisViewer,
    ApiResponse
  },
  computed: {
    teams() {
      return config.github.teams;
    },
    gitHubOrgName() {
      return config.github.org;
    },
    itemName() {
      return 'Code';//config.scope.type;
    },
    capitalizedItemName():string {
      return this.itemName.charAt(0).toUpperCase() + this.itemName.slice(1);
    },
    displayedViewName(): string {
      return config.scope.name;
    },
    isScopeOrganization() {
      return config.scope.type === 'organization';
    },
    teamName(){
      var teamName;
      if (config.github.team && config.github.team.trim() !== '')  {
        teamName = "| Team : " + config.github.team;
      } else {
        teamName = '';
      }
      return teamName;
    },
    mockedDataMessage() {
      return config.mockedData ? 'Using mock data - see README if unintended' : '';
    }
  },
  data () {
    return {
      tabItems: ['languages', 'editors', 'copilot chat', 'seat analysis', 'api response', 'more stats'],
      tab: null,
      selectedTeam: config.github.team || 'All Teams',
      componentsKey: '',
      metricsReady: false,
      metrics: [] as Metrics[],
      seatsReady: false,
      seats: [] as Seat[],
      apiError: undefined as string | undefined
    }
  },
  created() {
    this.tabItems.unshift(this.itemName);
    let urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has('team')) {
      this.selectedTeam = urlParams.get('team') || '';
      config.github.team=this.selectedTeam;
    } else {
      const cookieTeam = document.cookie.split('; ').find(row => row.startsWith('selectedTeam='));
      if (cookieTeam) {
        this.selectedTeam = cookieTeam.split('=')[1];
        config.github.team = this.selectedTeam;
      }
    }
    this.initializeData();
  },
  methods: {
    updateTeam(event: Event) {
      (this.$refs.teamSelect as HTMLSelectElement).disabled = true;
      console.log("updateTeam:" + event);
      const target = event.target as HTMLInputElement;
      if (target) {
        config.github.team = target.value == "org" ? 'All Teams' : target.value;
        const url = new URL(window.location.href);
        url.searchParams.set('team', target.value);
        window.history.pushState({}, '', url);
        this.componentsKey = config.github.team;
        this.selectedTeam = config.github.team;
        this.initializeData(); // Call the setup logic
      }
      // Sleep for 10 seconds before re-enabling the select element
      setTimeout(() => {
        (this.$refs.teamSelect as HTMLSelectElement).disabled = false;
      }, 3000);
    },
    initializeData() {
      console.log("initializeData: " + config.github.team);
      this.metricsReady = false;
      this.seatsReady = false;
      this.apiError = undefined;
      this.seats = [];
      this.metrics = [];
      // Save selected team to cookie
      document.cookie = `selectedTeam=${config.github.team}; path=/; max-age=31536000`; // 1 year expiration
      
      if(config.github.team && config.github.team.trim() !== '' && config.github.team.trim() !== 'All Teams') {
        getTeamMetricsApi().then(data => {
        this.metrics = data;

        // Set metricsReady to true after the call completes.
        this.metricsReady = true;

      }).catch(error => {
        console.log(error);
        // Check the status code of the error response
        if (error.response && error.response.status) {
          switch (error.response.status) {
            case 401:
              this.apiError = '401 Unauthorized access - check if your token in the .env file is correct.';
              break;
            case 404:
              this.apiError = `404 Not Found - is the ${config.scope.type} '${config.scope.name}' correct?`;
              break;
            default:
              this.apiError = error.message;
              break;
          }
        } else {
          // Update apiError with the error message
          this.apiError = error.message;
        }
        // Add a new line to the apiError message
        this.apiError += ' <br> If .env file is modified, restart the app for the changes to take effect.';
      });
      }

      if (this.metricsReady === false && (config.github.team.trim() == 'All Teams' || config.github.team.trim() == '')) {
        getMetricsApi().then(data => {
          this.metrics = data;

          // Set metricsReady to true after the call completes.
          this.metricsReady = true;
            
        }).catch(error => {
        console.log(error);
        // Check the status code of the error response
        if (error.response && error.response.status) {
          switch (error.response.status) {
            case 401:
              this.apiError = '401 Unauthorized access - check if your token in the .env file is correct.';
              break;
            case 404:
              this.apiError = `404 Not Found - is the ${config.scope.type} '${config.scope.name}' correct?`;
              break;
            default:
              this.apiError = error.message;
              break;
          }
        } else {
          // Update apiError with the error message
          this.apiError = error.message;
        }
        // Add a new line to the apiError message
        this.apiError += ' <br> If .env file is modified, restart the app for the changes to take effect.';
          
      });
    }
     
    getSeatsApi().then(data => {
        this.seats = data;
        if (config.github.team != "" && config.github.team != "All Teams") {
          this.seats = data.filter((seat) => {
            return seat.team === config.github.team;
          });
        }

        // Set seatsReady to true after the call completes.
        this.seatsReady= true;
          
      }).catch(error => {
      console.log(error);
      // Check the status code of the error response
      if (error.response && error.response.status) {
        switch (error.response.status) {
          case 401:
            this.apiError = '401 Unauthorized access - check if your token in the .env file is correct.';
            break;
          case 404:
            this.apiError = `404 Not Found - is the ${config.scope.type} '${config.scope.name}' correct?`;
            break;
          default:
            this.apiError = error.message;
            break;
        }
      } else {
        // Update apiError with the error message
        this.apiError = error.message;
      }
       // Add a new line to the apiError message
       this.apiError += ' <br> If .env file is modified, restart the app for the changes to take effect.';
    });
    }
  },
}
)
</script>

<style scoped>
.toolbar-title {
  white-space: nowrap;
  overflow: visible;
  text-overflow: clip;

}
.error-message {
  color: red;
}

.customSelect {
  color:white;
  position: absolute;
  margin-left: 15px;
  -webkit-appearance: menulist;
  box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
}
.customLabel {
  color:red;
}
.v-toolbar-title__placeholder {
  overflow: unset;
}
.toolbar-title {
  margin-inline-start: unset;
}
</style>
