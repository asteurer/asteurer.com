<script lang="ts">
    const pdfUrl: string = 'https://s3.us-east-2.amazonaws.com/asteurer.com-prod/resume.pdf';
  </script>

  <div class="pdf-container">
    <embed
      src={pdfUrl}
      type="application/pdf"
      width="100%"
      height="100%"
    />
  </div>

  <style>
    .pdf-container {
      width: 100%;
      height: 90vh;  /* Takes up 90% of the viewport height */
    }
  </style>