function output = transres_valence(decoding_out, chancelevel, cfg,data)

load valence_run_model.mat

y = model_rsa;
d = 1 - decoding_out.opt; % convert to dissimilarity matrix (1 - r)

%do not take diagonal of zeros from model nor data!
d_tril = tril(d,-1);
d_vector = d_tril(d_tril~=0);
y_vector = y(d_tril~=0);

%correlate model and data
r = corr(d_vector(:),y_vector(:),'Type','Spearman');

% force finite values for later z-transformation
r1 = (abs(r)+eps)>=1; % eps corrects for rounding errors in r
if any(r1(:))
    warning('CORRELATION_CLASSIFIER:ZCORRINF','Correlations of +1 or -1 found. Correcting to +/-0.99999 to avoid infinity for z-transformed correlations!')
    r(r1) = 0.99999*r(r1); % forces finite values
end

% translate to Fisher's z transformed values 
output = atanh(r);