import { LightningElement, track } from 'lwc';
import sendToExternalApi from '@salesforce/apex/BrandingFormController.sendToExternalApi';
import fetchCase from '@salesforce/apex/BrandingFormController.fetchCase';

export default class BrandingForm extends LightningElement {
    uploadedFiles = [];
    logo;
    banner;
    @track selectedColor;
    caseData;
    forUpdate = false;

    connectedCallback() {
        fetchCase()
        .then(result => {
            this.caseData = result;
            console.log(result);
            if(result.status != 'Closed' && result.status != 'Cancelled' && result.status != 'Rejected' && result.status != 'Not Approved'){
                this.logo = result.logoId;
                this.banner = result.bannerId;
                this.selectedColor = result.color;
                this.forUpdate = true;
            }
        })
        .catch(err => {
            this.error = err;
        });
    }

    handleLogoUploadFinished(event) {
        const files = event.detail.files;
        console.log(files);
        this.logo = files[0];
        this.uploadedFiles.push(...files.map(f => f.documentId));
    }

    handleBannerUploadFinished(event) {
        const files = event.detail.files;
        this.banner = files[0];
        this.uploadedFiles.push(...files.map(f => f.documentId));
    }

    handleColorChange(event) {
        this.selectedColor = event.target.value;
    }

    handleSubmit() {
        sendToExternalApi({ 
            fileIds: this.uploadedFiles, 
            color: this.selectedColor,
            forUpdate: this.forUpdate,
        }).then(() => {
            alert('Data sent to receiver org');
        }).catch(err => {
            console.error('Error sending data', err);
        });
    }
}