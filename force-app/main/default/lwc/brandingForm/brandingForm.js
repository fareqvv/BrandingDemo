import { LightningElement } from 'lwc';
import sendToExternalApi from '@salesforce/apex/BrandingFormController.sendToExternalApi';

export default class BrandingForm extends LightningElement {
    uploadedFiles = [];
    logo;
    banner;
    selectedColor;

    handleLogoUploadFinished(event) {
        const files = event.detail.files;
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
            color: this.selectedColor 
        }).then(() => {
            alert('Data sent to receiver org');
        }).catch(err => {
            console.error('Error sending data', err);
        });
    }
}