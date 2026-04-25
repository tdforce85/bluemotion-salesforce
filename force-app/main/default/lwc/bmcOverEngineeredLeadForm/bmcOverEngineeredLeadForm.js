import { LightningElement, track } from 'lwc';
import checkForDuplicates from '@salesforce/apex/OverEngineeredLeadController.checkForDuplicates';
import createLead from '@salesforce/apex/OverEngineeredLeadController.createLead';
// Note: ShowToastEvent intentionally not imported — it does not render on LWR Experience Cloud sites.
// All alerts go through the in-component snarky-alert banner instead.

export default class BmcOverEngineeredLeadForm extends LightningElement {
    @track enterpriseMode = false;
    @track currentStep = 1;
    @track platformFeaturesInvoked = 0;
    @track fieldsCaptured = 0;
    @track buttonDodgeCount = 0;
    @track progressGoingBackwards = false;
    @track fakeProgress = 0;
    @track showTermsModal = false;
    @track showDroneModal = false;
    @track showDuplicateModal = false;
    @track duplicateCheckResult = '';
    @track droneDeploymentStage = 0;
    @track loadingMessage = 'Initializing...';
    @track showConfetti = false;
    @track snarkyAlert = null; // { title, message, variant } — custom in-component alert (ShowToastEvent does not render in LWR)
    _alertTimer = null;
    @track archReviewStage = 0; // 0=pending, 1=still pending, 2=approved
    _archReviewTimers = [];

    // Form data
    @track formData = {
        firstName: '',
        lastName: '',
        email: '',
        company: '',
        phone: '',
        street: '',
        city: '',
        state: '',
        zip: ''
    };
    
    @track duplicateLeads = [];
    @track showDuplicateWarning = false;
    @track hadDuplicateWarning = false; // Track if we ever showed a warning
    @track isCheckingDuplicates = false;
    @track isSubmitting = false;
    @track debugLog = [];
    
    loadingMessages = [
        'Instantiating service layer...',
        'Invoking trigger handler...',
        'Checking governor limits...',
        'Wondering if this could\'ve been a validation rule...',
        'It could have.',
        'Proceeding anyway.'
    ];
    
    // 11 steps for Enterprise Mode
    enterpriseSteps = [
        {
            number: 1,
            title: 'The Basics',
            subtitle: 'Step 1 of 11. Yes, eleven. We take contact forms seriously.',
            commentary: 'Initializing first-party data capture sequence with custom LWC inputs, real-time duplicate detection, and @track decorator magic.'
        },
        {
            number: 2,
            title: 'Address Verification',
            subtitle: 'Because we need to know WHERE you are (for the drone army)',
            commentary: 'Geocoding your address via API callout. Rendering interactive map. Preparing Agentforce Drone Army deployment protocols.'
        },
        {
            number: 3,
            title: 'Company Intelligence',
            subtitle: 'Normally this is where we\'d charge $50k for a Data Cloud integration',
            commentary: 'Enriching company data with excessive API calls. Today it\'s free because this is a demo.'
        },
        {
            number: 4,
            title: 'Risk Assessment',
            subtitle: 'Running your submission through our 47-step approval process',
            commentary: 'Evaluating submission against enterprise governance framework. Spoiler: It was always going to be approved.'
        },
        {
            number: 5,
            title: 'The Enterprise Event Bus',
            subtitle: 'Your name and email are about to take a journey',
            commentary: 'Firing Platform Event → Consuming in Trigger → Invoking Queueable Apex. Total fields saved so far: 2.'
        },
        {
            number: 6,
            title: 'Additional Demographics',
            subtitle: 'Because 5 fields weren\'t enough',
            commentary: 'Collecting supplementary metadata for the marketing automation we haven\'t built yet.'
        },
        {
            number: 7,
            title: 'Preferences',
            subtitle: 'How shall we spam... I mean, nurture you?',
            commentary: 'Configuring communication preferences. Don\'t worry, we\'ll ignore these later.'
        },
        {
            number: 8,
            title: 'Terms & Conditions',
            subtitle: '47 pages of legal text you definitely won\'t read',
            commentary: 'Displaying enterprise-grade terms of service. Section 1: You agree this is over-engineered. Section 2: See Section 1.'
        },
        {
            number: 9,
            title: 'Final Validation',
            subtitle: 'Triple-checking everything we already validated',
            commentary: 'Re-validating all inputs with redundant validation rules, duplicate rules, and workflow rules that could\'ve been triggers.'
        },
        {
            number: 10,
            title: 'Architectural Review',
            subtitle: 'Waiting for architectural committee approval',
            commentary: 'Simulating approval process. Status: Pending... Pending... Approved! (It was instant, we just made you wait.)'
        },
        {
            number: 11,
            title: 'The Reveal',
            subtitle: 'Mock debug log of everything that fired',
            commentary: 'If this made you laugh and slightly concerned about my priorities, imagine what I could build for your org.'
        }
    ];
    
    // 3 steps for Normal Mode
    normalSteps = [
        {
            number: 1,
            title: 'Contact Information',
            subtitle: 'A sensible, normal contact form',
            commentary: 'Just name, email, and company. Like a reasonable person would design.'
        }
    ];
    
    connectedCallback() {
        this.incrementPlatformFeatures('connectedCallback lifecycle hook');
        this.incrementPlatformFeatures('LightningElement base class extension');
        this.incrementPlatformFeatures('@track decorator usage');
        this.startFakeProgressSimulator();
    }
    
    get steps() {
        return this.enterpriseMode ? this.enterpriseSteps : this.normalSteps;
    }
    
    get currentStepConfig() {
        return this.steps[this.currentStep - 1];
    }
    
    get progressPercentage() {
        if (this.enterpriseMode && this.progressGoingBackwards) {
            return this.fakeProgress;
        }
        return ((this.currentStep - 1) / (this.steps.length - 1)) * 100;
    }
    
    get progressStyle() {
        return `width: ${this.progressPercentage}%`;
    }
    
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }
    get isStep7() { return this.currentStep === 7; }
    get isStep8() { return this.currentStep === 8; }
    get isStep9() { return this.currentStep === 9; }
    get isStep10() { return this.currentStep === 10; }
    get isStep11() { return this.currentStep === 11; }
    
    get isFirstStep() {
        return this.currentStep === 1;
    }
    
    get isLastStep() {
        return this.currentStep === this.steps.length;
    }
    
    get nextButtonLabel() {
        if (!this.enterpriseMode) {
            return 'Submit';
        }
        if (this.currentStep === 1) return 'Proceed to Next Unnecessary Step';
        if (this.currentStep === 8) return 'I Agree (pending architectural review)';
        if (this.currentStep === 10) {
            return this.archReviewApproved ? 'Approved! Proceeding...' : 'Awaiting Approval...';
        }
        if (this.isLastStep) return '🚀 DEPLOY TO PRODUCTION';
        return 'Continue the Journey';
    }

    get archReviewStillPending() {
        return this.archReviewStage >= 1;
    }
    get archReviewApproved() {
        return this.archReviewStage >= 2;
    }
    get archReviewSpinning() {
        return this.archReviewStage < 2;
    }
    get isNextDisabled() {
        return this.isSubmitting || (this.currentStep === 10 && this.enterpriseMode && !this.archReviewApproved);
    }

    get mapMarkers() {
        const { street, city, state, zip } = this.formData;
        if (!street && !city && !state && !zip) {
            return [];
        }
        return [{
            location: {
                Street: street || '',
                City: city || '',
                State: state || '',
                PostalCode: zip || '',
                Country: 'USA'
            },
            title: 'Drone deployment target',
            description: 'Acquired. Standing by for dispatch order.'
        }];
    }

    get hasMapAddress() {
        const { street, city, zip } = this.formData;
        // Require at least street + (city OR zip) before attempting geocode.
        return Boolean(street && (city || zip));
    }

    get isDroneDeploying() {
        return this.droneDeploymentStage === 1;
    }
    get isDroneFailed() {
        return this.droneDeploymentStage >= 2;
    }
    get isDroneAssertion() {
        return this.droneDeploymentStage >= 3;
    }
    
    get stats() {
        return `Platform Features: ${this.platformFeaturesInvoked} | Fields: ${this.fieldsCaptured}/9`;
    }
    
    get modeToggleLabel() {
        return this.enterpriseMode ? 'Switch to Normal Mode' : 'Switch to Enterprise Architecture Mode';
    }
    
    handleModeToggle() {
        this.enterpriseMode = !this.enterpriseMode;
        this.currentStep = 1;
        this.platformFeaturesInvoked = 0;
        this.fieldsCaptured = 0;
        this.buttonDodgeCount = 0;
        this.incrementPlatformFeatures('Mode toggle invocation');
        
        if (this.enterpriseMode) {
            this.showToast(
                'Enterprise Mode Activated',
                'Buckle up. You\'re about to experience what happens when architects have too much time.',
                'info'
            );
        }
    }
    
    startFakeProgressSimulator() {
        if (this.enterpriseMode) {
            setInterval(() => {
                if (this.currentStep === 4 && this.fakeProgress < 90) {
                    this.fakeProgress += 5;
                    if (this.fakeProgress >= 90 && !this.progressGoingBackwards) {
                        this.progressGoingBackwards = true;
                        setTimeout(() => {
                            this.fakeProgress = 40;
                            this.showToast('Progress Update', 'Sorry, we found more architecture to add.', 'warning');
                        }, 500);
                    }
                }
            }, 500);
        }
    }
    
    incrementPlatformFeatures(feature) {
        this.platformFeaturesInvoked++;
        console.log(`🎯 Platform Feature Invoked [${this.platformFeaturesInvoked}]: ${feature}`);
        this.addToDebugLog(`[${new Date().toISOString()}] ${feature}`);
    }
    
    addToDebugLog(message) {
        this.debugLog = [...this.debugLog, message];
    }
    
    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.incrementPlatformFeatures(`@track reactivity for ${field} field`);
        this.incrementPlatformFeatures('Event bubbling and handling');
        
        this.formData[field] = value;
        
        // Clear duplicate warning when email field changes
        if (field === 'email' && this.hadDuplicateWarning) {
            this.showDuplicateWarning = false;
            this.duplicateLeads = [];
            this.hadDuplicateWarning = false;
            
            // Snarky alert when user tries to change email after seeing duplicates.
            this.showToast(
                'Sneaky, Sneaky! 🕵️',
                'Trying to sneak past us with another email eh? Fine...we\'re too lazy to code for that anyway.',
                'info'
            );
            this.incrementPlatformFeatures('Duplicate evasion detection');
        } else if (field === 'email') {
            // Just clear in case there was no warning
            this.duplicateLeads = [];
            this.showDuplicateWarning = false;
        }
        
        if (value && value.trim()) {
            this.fieldsCaptured = Object.values(this.formData).filter(v => v && v.trim()).length;
            this.incrementPlatformFeatures('Array.filter() method on form values');
        }
    }
    
    handleBlur(event) {
        const field = event.target.dataset.field;
        this.incrementPlatformFeatures('Blur event handling');

        // Fire dupe check only once first name, last name, and email are all filled.
        // Trigger on blur of any of the three so the order they're filled doesn't matter.
        const dupeCheckFields = ['firstName', 'lastName', 'email'];
        if (!dupeCheckFields.includes(field)) {
            return;
        }
        const { firstName, lastName, email } = this.formData;
        if (firstName && lastName && email) {
            this.checkDuplicates();
        }
    }

    get hasDuplicates() {
        return this.duplicateLeads && this.duplicateLeads.length > 0;
    }
    
    async checkDuplicates() {
        console.log('🔍 DUPLICATE CHECK STARTED');
        this.isCheckingDuplicates = true;
        this.incrementPlatformFeatures('Imperative Apex call preparation');
        this.incrementPlatformFeatures('Async/await JavaScript syntax');
        
        try {
            console.log('📧 Calling checkForDuplicates with:', {
                email: this.formData.email,
                firstName: this.formData.firstName,
                lastName: this.formData.lastName
            });
            
            const duplicates = await checkForDuplicates({
                email: this.formData.email,
                firstName: this.formData.firstName,
                lastName: this.formData.lastName
            });
            
            console.log('✅ Duplicate check returned:', duplicates);
            console.log('📊 Number of duplicates:', duplicates ? duplicates.length : 0);
            
            this.incrementPlatformFeatures('@AuraEnabled Apex method invocation');
            this.incrementPlatformFeatures('SOQL query execution (server-side)');
            
            this.duplicateLeads = duplicates;
            this.showDuplicateWarning = duplicates && duplicates.length > 0;
            
            // Set flag if we found duplicates
            if (this.showDuplicateWarning) {
                this.hadDuplicateWarning = true;
            }
            
            // ALWAYS show modal to confirm the check ran
            this.duplicateCheckResult = `Duplicate check complete! Found ${duplicates ? duplicates.length : 0} duplicate(s) for email: ${this.formData.email}`;
            
            console.log('🎯 Setting showDuplicateModal to TRUE');
            console.log('📝 Modal message:', this.duplicateCheckResult);
            this.showDuplicateModal = true;
            console.log('✔️ showDuplicateModal is now:', this.showDuplicateModal);
            
            if (this.showDuplicateWarning) {
                this.incrementPlatformFeatures('Duplicate detection warning display');
            } else {
                console.log('ℹ️ No duplicates found');
            }
            
        } catch (error) {
            this.incrementPlatformFeatures('Error handling with try-catch');
            console.error('❌ Duplicate check failed:', error);
            console.error('Error body:', error.body);
            console.error('Error message:', error.body?.message);
            
            // ALSO show modal on error to prove it's working
            this.duplicateCheckResult = `Error checking duplicates: ${error.body?.message || error.message}`;
            this.showDuplicateModal = true;
            console.log('🎯 Setting showDuplicateModal to TRUE (error case)');
            
            this.showToast(
                'Duplicate Check Failed',
                'Error checking for duplicates: ' + (error.body?.message || error.message),
                'error'
            );
        } finally {
            this.isCheckingDuplicates = false;
            this.incrementPlatformFeatures('Finally block execution');
            console.log('🏁 Duplicate check complete. showDuplicateModal =', this.showDuplicateModal);
        }
    }
    
    handlePrevious() {
        if (this.currentStep > 1) {
            this.currentStep--;
            this.incrementPlatformFeatures('Step navigation (backward)');
        }
    }
    
    handleNext() {
        if (this.enterpriseMode && this.buttonDodgeCount < 3 && this.currentStep === 2) {
            this.dodgeButton();
            return;
        }

        // Block manual advance during the arch review animation — let auto-advance fire instead.
        if (this.enterpriseMode && this.currentStep === 10 && !this.archReviewApproved) {
            return;
        }

        if (!this.validateCurrentStep()) {
            return;
        }

        this.incrementPlatformFeatures('Step validation logic');

        if (this.currentStep === 8 && this.enterpriseMode) {
            this.showTermsModal = true;
            return;
        }

        if (this.isLastStep) {
            this.handleSubmit();
        } else {
            this.currentStep++;
            this.incrementPlatformFeatures('Step navigation (forward)');

            if (this.enterpriseMode && this.currentStep === 5) {
                this.simulateEventBus();
            }
            if (this.enterpriseMode && this.currentStep === 10) {
                this.simulateArchReview();
            }
        }
    }
    
    dodgeButton() {
        this.buttonDodgeCount++;
        const button = this.template.querySelector('.next-button');
        if (button) {
            const randomX = Math.random() * 100 - 50;
            const randomY = Math.random() * 100 - 50;
            button.style.transform = `translate(${randomX}px, ${randomY}px)`;
            
            this.showToast(
                'Ha, too slow!',
                `Try again. (Attempt ${this.buttonDodgeCount}/3)`,
                'info'
            );
            
            if (this.buttonDodgeCount >= 3) {
                button.style.transform = '';
            }
        }
    }
    
    handleDroneDeployment() {
        this.showDroneModal = true;
        this.droneDeploymentStage = 1;
        this.incrementPlatformFeatures('Agentforce Drone Army deployment initiated');
        
        setTimeout(() => {
            this.droneDeploymentStage = 2;
            setTimeout(() => {
                this.droneDeploymentStage = 3;
                setTimeout(() => {
                    this.showDroneModal = false;
                    this.droneDeploymentStage = 0;
                }, 3000);
            }, 2000);
        }, 2000);
    }
    
    closeTermsModal() {
        this.showTermsModal = false;
        this.currentStep++;
        this.incrementPlatformFeatures('Terms & Conditions acceptance (without reading)');
    }
    
    closeDroneModal() {
        this.showDroneModal = false;
        this.droneDeploymentStage = 0;
    }
    
    closeDuplicateModal() {
        this.showDuplicateModal = false;
    }
    
    simulateEventBus() {
        this.addToDebugLog('[EVENT BUS] Firing Platform Event: Lead_Submission__e');
        this.incrementPlatformFeatures('Platform Event publication');

        setTimeout(() => {
            this.addToDebugLog('[TRIGGER] LeadSubmissionEventTrigger.trigger executed');
            this.incrementPlatformFeatures('Platform Event trigger consumption');

            setTimeout(() => {
                this.addToDebugLog('[QUEUEABLE] LeadEnrichmentQueueable.execute() invoked');
                this.incrementPlatformFeatures('Queueable Apex execution');
            }, 500);
        }, 500);
    }

    simulateArchReview() {
        // Reset and clear any prior timers in case the user bounced back into this step.
        this.archReviewStage = 0;
        this._archReviewTimers.forEach(t => clearTimeout(t));
        this._archReviewTimers = [];

        this.addToDebugLog('[APPROVAL] Submitted to Architectural Committee for review');

        this._archReviewTimers.push(setTimeout(() => {
            this.archReviewStage = 1;
            this.addToDebugLog('[APPROVAL] Still pending. Committee is debating tab vs. spaces.');
        }, 1500));

        this._archReviewTimers.push(setTimeout(() => {
            this.archReviewStage = 2;
            this.addToDebugLog('[APPROVAL] APPROVED. (It was always going to be approved.)');
            this.incrementPlatformFeatures('Architectural review approval');
        }, 3000));

        this._archReviewTimers.push(setTimeout(() => {
            // Only auto-advance if the user is still on this step.
            if (this.currentStep === 10 && this.enterpriseMode) {
                this.currentStep = 11;
                this.incrementPlatformFeatures('Auto-advance after architectural review');
            }
        }, 4200));
    }
    
    validateCurrentStep() {
        let isValid = true;
        let errorMessage = '';
        
        this.incrementPlatformFeatures('Form validation invocation');
        
        if (this.currentStep === 1) {
            if (!this.formData.lastName) {
                errorMessage = 'Last Name is required (obviously, we need to address you formally)';
                isValid = false;
            } else if (!this.formData.email) {
                errorMessage = 'Email is required (how else will we spam... I mean, nurture you?)';
                isValid = false;
            } else if (!this.formData.email.includes('@')) {
                errorMessage = 'Email must contain @ symbol (basic email validation engaged)';
                isValid = false;
            }
        } else if (this.currentStep === 3 && this.enterpriseMode) {
            if (!this.formData.company) {
                errorMessage = 'Company is required (we need to know who to invoice)';
                isValid = false;
            }
        }
        
        if (!isValid) {
            this.incrementPlatformFeatures('Validation error display');
            this.showToast('Validation Failed', errorMessage, 'error');
        }
        
        return isValid;
    }
    
    async handleSubmit() {
        this.isSubmitting = true;
        this.incrementPlatformFeatures('Form submission initiation');
        
        if (this.enterpriseMode) {
            await this.cycleLoadingMessages();
        }
        
        try {
            await createLead({
                leadData: this.formData
            });
            
            this.incrementPlatformFeatures('Lead DML operation (INSERT)');
            this.incrementPlatformFeatures('Database transaction commit');
            
            if (this.enterpriseMode) {
                this.showConfetti = true;
                setTimeout(() => {
                    this.showConfetti = false;
                }, 5000);
            }
            
            this.showToast(
                'Lead Created Successfully! 🎉',
                `Lead ID: yeah...right. ${this.enterpriseMode ? 'You survived all 11 steps. A sales rep will contact you... eventually.' : 'Thank you for your submission.'}`,
                'success'
            );
            
            this.resetForm();
            
        } catch (error) {
            this.incrementPlatformFeatures('Error handling with try-catch');
            console.error('Lead creation failed:', error);
            this.showToast(
                'Lead Creation Failed',
                'Despite invoking ' + this.platformFeaturesInvoked + ' platform features, we still failed: ' + error.body?.message,
                'error'
            );
        } finally {
            this.isSubmitting = false;
        }
    }
    
    async cycleLoadingMessages() {
        for (let msg of this.loadingMessages) {
            this.loadingMessage = msg;
            await new Promise(resolve => setTimeout(resolve, 800));
        }
    }
    
    resetForm() {
        this.currentStep = 1;
        this.formData = {
            firstName: '',
            lastName: '',
            email: '',
            company: '',
            phone: '',
            street: '',
            city: '',
            state: '',
            zip: ''
        };
        this.duplicateLeads = [];
        this.showDuplicateWarning = false;
        this.fieldsCaptured = 0;
        this.debugLog = [];
        
        this.incrementPlatformFeatures('Form reset operation');
    }
    
    showToast(title, message, variant) {
        this.incrementPlatformFeatures('Custom in-component alert dispatch');
        this.snarkyAlert = { title, message, variant: variant || 'info' };
        if (this._alertTimer) {
            clearTimeout(this._alertTimer);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._alertTimer = setTimeout(() => {
            this.snarkyAlert = null;
            this._alertTimer = null;
        }, 5000);
    }

    closeSnarky() {
        this.snarkyAlert = null;
        if (this._alertTimer) {
            clearTimeout(this._alertTimer);
            this._alertTimer = null;
        }
    }

    get snarkyAlertClass() {
        const variant = (this.snarkyAlert && this.snarkyAlert.variant) || 'info';
        return `snarky-alert snarky-alert--${variant}`;
    }
}